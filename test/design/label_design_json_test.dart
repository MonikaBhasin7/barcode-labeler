import 'dart:convert';
import 'dart:typed_data';

import 'package:barcode_labeler/features/design/data/models/label_design.dart';
import 'package:barcode_labeler/features/design/data/models/label_font.dart';
import 'package:barcode_labeler/features/design/data/models/label_item.dart';
import 'package:barcode_labeler/features/design/data/models/label_value.dart';
import 'package:flutter_test/flutter_test.dart';

import '../printing/test_designs.dart';

void main() {
  test('a design survives saving and opening again', () {
    final design = stockLabelDesign.copyWith(
      items: [
        ...stockLabelDesign.items,
        PictureItem(
          id: 'logo',
          name: 'Logo',
          frame: const ItemFrame(x: 1, y: 1, width: 5, height: 5),
          imageBytes: Uint8List.fromList([1, 2, 3, 4]),
        ),
      ],
      dataFile: const DataFileLink(
        path: r'C:\Labels\E7.xlsx',
        sheetName: 'Sheet1',
      ),
    );

    final reopened = LabelDesign.fromJson(
      jsonDecode(jsonEncode(design.toJson())) as Map<String, dynamic>,
    );

    expect(jsonEncode(reopened.toJson()), jsonEncode(design.toJson()));
    expect(reopened.dataFile?.path, r'C:\Labels\E7.xlsx');
    expect(reopened.items.whereType<TextItem>().map((text) => text.font), [
      const BuiltInFont(LabelFont.roboto),
      const BuiltInFont(LabelFont.robotoCondensed),
    ]);
    expect((reopened.items.last as PictureItem).imageBytes, [1, 2, 3, 4]);
  });

  test('a file from another program is refused', () {
    expect(
      () => LabelDesign.fromJson({'format': 'something-else'}),
      throwsFormatException,
    );
  });

  test('a design knows which Excel columns it needs', () {
    expect(stockLabelDesign.excelColumnsUsed, {'Name', 'Code'});
    expect(stockLabelDesign.serialNumberSources.single.key, 'serial');
  });

  test('joined parts count their own columns, serials and questions', () {
    const design = LabelDesign(
      id: 'parts',
      name: 'Parts',
      sheet: SheetLayout.wholeA4Page,
      items: [
        BarcodeItem(
          id: 'joined',
          name: 'Barcode 1',
          frame: ItemFrame(x: 0, y: 0, width: 50, height: 20),
          value: LabelValue(
            kind: ValueSourceKind.joinedParts,
            parts: [
              ValuePart(
                id: 'a',
                value: LabelValue(
                  kind: ValueSourceKind.excelColumn,
                  excelColumn: 'Lot',
                ),
              ),
              ValuePart(
                id: 'b',
                value: LabelValue(kind: ValueSourceKind.serialNumber),
              ),
              ValuePart(
                id: 'c',
                value: LabelValue(
                  kind: ValueSourceKind.typedWhenPrinting,
                  question: 'Shift?',
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final reopened = LabelDesign.fromJson(
      jsonDecode(jsonEncode(design.toJson())) as Map<String, dynamic>,
    );

    expect(reopened.excelColumnsUsed, {'Lot'});
    expect(reopened.serialNumberSources.single.key, 'joined/b');
    expect(reopened.serialNumberSources.single.label, 'Barcode 1 · part 2');
    expect(reopened.printQuestions.single.prompt, 'Shift?');
  });

  test('an old design without a font opens with Roboto', () {
    final text = TextItem.fromJson({
      'kind': 'text',
      'id': 'old',
      'name': 'Old text',
      'frame': {'x': 0, 'y': 0, 'width': 10, 'height': 5},
      'value': {'kind': 'fixedText', 'fixedText': 'Hi'},
    });

    expect(text.font, robotoFont);
  });

  test('a font from this PC is saved by its name', () {
    const text = TextItem(
      id: 'name',
      name: 'Name',
      frame: ItemFrame(x: 0, y: 0, width: 40, height: 8),
      value: LabelValue(),
      font: InstalledFont('Arial'),
      bold: true,
    );

    final json = jsonDecode(jsonEncode(text.toJson())) as Map<String, dynamic>;
    final reopened = TextItem.fromJson(json);

    expect(json['installedFont'], 'Arial');
    expect(json.containsKey('font'), isFalse);
    expect(reopened.font, const InstalledFont('Arial'));
    expect(reopened.bold, isTrue);
  });

  test('the number under a barcode keeps its font', () {
    const barcode = BarcodeItem(
      id: 'code',
      name: 'Barcode 1',
      frame: ItemFrame(x: 0, y: 0, width: 50, height: 18),
      value: LabelValue(fixedText: '123456'),
      numberFont: InstalledFont('Arial'),
    );

    final reopened = BarcodeItem.fromJson(
      jsonDecode(jsonEncode(barcode.toJson())) as Map<String, dynamic>,
    );
    final old = BarcodeItem.fromJson({
      'kind': 'barcode',
      'id': 'old',
      'name': 'Old barcode',
      'frame': {'x': 0, 'y': 0, 'width': 50, 'height': 18},
      'value': {'kind': 'fixedText', 'fixedText': '123456'},
    });

    expect(reopened.numberFont, const InstalledFont('Arial'));
    expect(old.numberFont, robotoFont);
  });

  test('a barcode number font counts only when the number is shown', () {
    const shown = BarcodeItem(
      id: 'shown',
      name: 'Shown',
      frame: ItemFrame(x: 0, y: 0, width: 50, height: 18),
      value: LabelValue(fixedText: '123456'),
      numberFont: BuiltInFont(LabelFont.tinos),
    );
    final hidden = BarcodeItem(
      id: 'hidden',
      name: 'Hidden',
      frame: const ItemFrame(x: 0, y: 20, width: 50, height: 18),
      value: const LabelValue(fixedText: '123456'),
      showText: false,
      numberFont: const BuiltInFont(LabelFont.lato),
    );
    const design = LabelDesign(
      id: 'numbers',
      name: 'Numbers',
      sheet: SheetLayout.wholeA4Page,
      items: [shown],
    );

    expect(design.copyWith(items: [shown, hidden]).fontsUsed, {
      robotoFont,
      const BuiltInFont(LabelFont.tinos),
    });
  });

  test('a font from this PC never hides a built-in font', () {
    expect(isBuiltInFontName('Roboto Condensed'), isTrue);
    expect(isBuiltInFontName('tinos'), isTrue);
    expect(isBuiltInFontName('Arial'), isFalse);
  });
}
