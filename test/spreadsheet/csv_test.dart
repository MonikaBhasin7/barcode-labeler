import 'package:barcode_labeler/features/spreadsheet/data/models/spreadsheet_table.dart';
import 'package:barcode_labeler/features/spreadsheet/data/spreadsheet_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads quoted fields, commas and new lines inside quotes', () {
    final cells = parseCsv(
      'Code,Name\r\n001,"Shirt, blue"\n002,"Say ""hi"""\n',
    );

    expect(cells, [
      ['Code', 'Name'],
      ['001', 'Shirt, blue'],
      ['002', 'Say "hi"'],
    ]);
  });

  test('uses semicolons when the file is separated by them', () {
    final table = tableFromCells(SheetCells(cells: parseCsv('Code;Qty\nA1;5')));

    expect(table.rows.single, {'Code': 'A1', 'Qty': '5'});
  });

  test('names blank and repeated headers so every column is usable', () {
    final table = tableFromCells(
      SheetCells(cells: parseCsv('Code,,Code\n1,2,3')),
    );

    expect(table.headers, ['Code', 'Column B', 'Code (2)']);
  });
}
