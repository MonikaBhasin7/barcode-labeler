import 'package:barcode_labeler/features/design/application/label_value_resolver.dart';
import 'package:barcode_labeler/features/design/data/models/label_item.dart';
import 'package:barcode_labeler/features/design/data/models/label_value.dart';
import 'package:flutter_test/flutter_test.dart';

const ItemFrame anyFrame = ItemFrame(x: 0, y: 0, width: 40, height: 10);

LabelValueContext contextFor(int recordIndex, {Map<String, String>? row}) {
  return LabelValueContext(
    row: row ?? const {},
    recordIndex: recordIndex,
    serialStarts: const {},
    typedAnswers: const {},
    today: DateTime(2026, 10, 26),
  );
}

void main() {
  test('serial numbers follow start, step and repeat every', () {
    const rule = SerialNumberRule(start: 2, step: 1, repeatEvery: 3);

    final values = [for (var i = 0; i < 7; i++) serialValueAt(rule, 2, i)];

    expect(values, [2, 2, 2, 3, 3, 3, 4]);
  });

  test('serial numbers can count down and keep leading zeros', () {
    const rule = SerialNumberRule(
      start: 100,
      step: 5,
      minDigits: 5,
      countDown: true,
    );

    expect(serialNumberText(rule, 100, 0), '00100');
    expect(serialNumberText(rule, 100, 2), '00090');
  });

  test('the next print continues after the last group printed', () {
    const everyLabel = SerialNumberRule(start: 1000001);
    const everyThird = SerialNumberRule(start: 1, repeatEvery: 3);

    expect(serialStartAfterPrinting(everyLabel, 1000001, 19), 1000020);
    expect(serialStartAfterPrinting(everyThird, 1, 4), 3);
  });

  test('values join prefix, source and suffix', () {
    const item = TextItem(
      id: 'code',
      name: 'Code',
      frame: anyFrame,
      value: LabelValue(
        kind: ValueSourceKind.excelColumn,
        excelColumn: 'SKU',
        prefix: 'SKU-',
        suffix: '/A',
      ),
    );
    final resolver = LabelValueResolver([item]);

    final text = resolver.resolve(item, contextFor(0, row: {'SKU': '778'}));

    expect(text, 'SKU-778/A');
  });

  test('a stored serial start overrides the design start', () {
    const item = BarcodeItem(
      id: 'serial',
      name: 'Serial',
      frame: anyFrame,
      value: LabelValue(
        kind: ValueSourceKind.serialNumber,
        serial: SerialNumberRule(start: 1000001),
      ),
    );
    final resolver = LabelValueResolver([item]);
    final context = LabelValueContext(
      row: const {},
      recordIndex: 1,
      serialStarts: const {'serial': 1000020},
      typedAnswers: const {},
      today: DateTime(2026),
    );

    expect(resolver.resolve(item, context), '1000021');
  });

  test('dates use the chosen pattern and added days', () {
    const rule = DateRule(pattern: 'dd-MMM-yyyy', addDays: 10);

    expect(dateText(rule, DateTime(2026, 10, 26)), '05-Nov-2026');
  });

  test('an item can copy the value of another item', () {
    const barcode = BarcodeItem(
      id: 'barcode',
      name: 'Barcode 1',
      frame: anyFrame,
      value: LabelValue(fixedText: 'ABC123'),
    );
    const caption = TextItem(
      id: 'caption',
      name: 'Caption',
      frame: anyFrame,
      value: LabelValue(
        kind: ValueSourceKind.sameAsItem,
        sameAsItemId: 'barcode',
        prefix: 'No. ',
      ),
    );
    final resolver = LabelValueResolver([barcode, caption]);

    expect(resolver.resolve(caption, contextFor(0)), 'No. ABC123');
  });

  test('a typed answer fills a value typed when printing', () {
    const item = TextItem(
      id: 'batch',
      name: 'Batch',
      frame: anyFrame,
      value: LabelValue(
        kind: ValueSourceKind.typedWhenPrinting,
        question: 'Batch number?',
        prefix: 'Batch ',
      ),
    );
    final resolver = LabelValueResolver([item]);
    final context = LabelValueContext(
      row: const {},
      recordIndex: 0,
      serialStarts: const {},
      typedAnswers: const {'batch': 'B-17'},
      today: DateTime(2026),
    );

    expect(resolver.resolve(item, context), 'Batch B-17');
  });

  test('joined parts are put together in order', () {
    const item = BarcodeItem(
      id: 'joined',
      name: 'Joined',
      frame: anyFrame,
      value: LabelValue(
        kind: ValueSourceKind.joinedParts,
        parts: [
          ValuePart(
            id: 'p1',
            value: LabelValue(fixedText: 'B'),
          ),
          ValuePart(
            id: 'p2',
            value: LabelValue(
              kind: ValueSourceKind.excelColumn,
              excelColumn: 'Code',
            ),
          ),
          ValuePart(
            id: 'p3',
            value: LabelValue(
              kind: ValueSourceKind.serialNumber,
              serial: SerialNumberRule(start: 1, minDigits: 4),
            ),
          ),
          ValuePart(
            id: 'p4',
            value: LabelValue(
              kind: ValueSourceKind.date,
              date: DateRule(pattern: 'ddMMyy'),
            ),
          ),
          ValuePart(
            id: 'p5',
            value: LabelValue(kind: ValueSourceKind.typedWhenPrinting),
          ),
        ],
      ),
    );
    final resolver = LabelValueResolver([item]);
    final context = LabelValueContext(
      row: const {'Code': 'X9'},
      recordIndex: 2,
      serialStarts: const {'joined/p3': 50},
      typedAnswers: const {'joined/p5': 'Z'},
      today: DateTime(2026, 10, 26),
    );

    expect(resolver.resolve(item, context), 'BX90052261026Z');
  });
}
