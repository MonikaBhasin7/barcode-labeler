import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:barcode_labeler/features/spreadsheet/data/models/spreadsheet_table.dart';
import 'package:barcode_labeler/features/spreadsheet/data/spreadsheet_reader.dart';
import 'package:barcode_labeler/features/spreadsheet/data/xlsx_workbook.dart';
import 'package:flutter_test/flutter_test.dart';

const String workbookXml = '''<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Stock" sheetId="1" r:id="rId1"/>
    <sheet name="Empty" sheetId="2" r:id="rId2"/>
  </sheets>
</workbook>''';

const String relationsXml = '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="worksheet" Target="/xl/worksheets/sheet2.xml"/>
</Relationships>''';

const String sharedStringsXml = '''<?xml version="1.0" encoding="UTF-8"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <si><t>Barcode</t></si>
  <si><t>Name</t></si>
  <si><t>Price</t></si>
  <si><t>Code</t></si>
  <si><t>Made</t></si>
  <si><r><t>Blue </t></r><r><t>Shirt</t></r><rPh><t>hint</t></rPh></si>
</sst>''';

const String stylesXml = '''<?xml version="1.0" encoding="UTF-8"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <numFmts count="3">
    <numFmt numFmtId="164" formatCode="000000"/>
    <numFmt numFmtId="165" formatCode="&quot;LOT-&quot;000"/>
    <numFmt numFmtId="166" formatCode="d\\-mmm\\-yy"/>
  </numFmts>
  <cellXfs count="7">
    <xf numFmtId="0"/>
    <xf numFmtId="2"/>
    <xf numFmtId="164"/>
    <xf numFmtId="14"/>
    <xf numFmtId="165"/>
    <xf numFmtId="166"/>
    <xf numFmtId="3"/>
  </cellXfs>
</styleSheet>''';

const String stockSheetXml = '''<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>0</v></c>
      <c r="B1" t="s"><v>1</v></c>
      <c r="C1" t="s"><v>2</v></c>
      <c r="D1" t="s"><v>3</v></c>
      <c r="E1" t="s"><v>4</v></c>
    </row>
    <row r="2">
      <c r="A2"><f>A1+1</f><v>1000001</v></c>
      <c r="B2" t="s"><v>5</v></c>
      <c r="C2" s="1"><v>12.5</v></c>
      <c r="D2" s="2"><v>123</v></c>
      <c r="E2" s="3"><v>46321</v></c>
    </row>
    <row r="3"/>
    <row r="4">
      <c r="A4" t="str"><f>"X"&amp;"Y"</f><v>XY</v></c>
      <c r="C4"><v>0.30000000000000004</v></c>
      <c r="D4"><v>8901234567890</v></c>
      <c r="Z4" s="2"/>
    </row>
    <row r="5" hidden="1">
      <c r="A5"><v>99</v></c>
    </row>
    <row r="6">
      <c r="A6" s="4"><v>12</v></c>
      <c r="B6" t="inlineStr"><is><t>Line one_x000D_
Line two</t></is></c>
      <c r="C6" s="6"><v>1234567</v></c>
      <c r="E6" s="5"><v>46321</v></c>
    </row>
    <row r="9">
      <c r="XFD9" s="2"/>
    </row>
  </sheetData>
</worksheet>''';

const String emptySheetXml = '''<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData/></worksheet>''';

Uint8List buildTestWorkbook() {
  final archive = Archive();
  void addFile(String name, String text) {
    final bytes = utf8.encode(text);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  addFile('xl/workbook.xml', workbookXml);
  addFile('xl/_rels/workbook.xml.rels', relationsXml);
  addFile('xl/sharedStrings.xml', sharedStringsXml);
  addFile('xl/styles.xml', stylesXml);
  addFile('xl/worksheets/sheet1.xml', stockSheetXml);
  addFile('xl/worksheets/sheet2.xml', emptySheetXml);
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  final workbook = XlsxWorkbook.decode(buildTestWorkbook());

  test('lists the sheets in workbook order', () {
    expect(workbook.sheetNames, ['Stock', 'Empty']);
  });

  test('reads cells the way Excel shows them', () {
    final table = tableFromCells(workbook.readSheetCells('Stock'));

    expect(table.headers, ['Barcode', 'Name', 'Price', 'Code', 'Made']);
    expect(table.rows.length, 3);
    expect(table.rows[0], {
      'Barcode': '1000001',
      'Name': 'Blue Shirt',
      'Price': '12.50',
      'Code': '000123',
      'Made': '26/10/2026',
    });
    expect(table.rows[1]['Barcode'], 'XY');
    expect(table.rows[1]['Name'], '');
    expect(table.rows[1]['Price'], '0.3');
    expect(table.rows[1]['Code'], '8901234567890');
  });

  test('keeps Excel row numbers and leaves out hidden rows', () {
    final table = tableFromCells(workbook.readSheetCells('Stock'));

    expect(table.excelRowNumbers, [2, 4, 6]);
    expect(table.hiddenRowCount, 1);
  });

  test('empty cells with only formatting do not add columns', () {
    final table = tableFromCells(workbook.readSheetCells('Stock'));

    expect(table.headers.length, 5);
  });

  test('shows fixed text, thousands, dates and line breaks like Excel', () {
    final table = tableFromCells(workbook.readSheetCells('Stock'));
    final row = table.rows[2];

    expect(row['Barcode'], 'LOT-012');
    expect(row['Name'], 'Line one\nLine two');
    expect(row['Price'], '1,234,567');
    expect(row['Made'], '26-Oct-26');
  });

  test('an empty sheet gives an empty table', () {
    final table = tableFromCells(workbook.readSheetCells('Empty'));

    expect(table.headers, isEmpty);
    expect(table.rows, isEmpty);
  });

  test('a file that is not a zip is refused with a clear message', () {
    expect(
      () => XlsxWorkbook.decode(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<SpreadsheetReadException>()),
    );
  });
}
