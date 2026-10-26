import 'dart:convert';
import 'dart:typed_data';

import 'package:barcode_labeler/features/design/data/models/label_design.dart';
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
}
