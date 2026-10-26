import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'models/spreadsheet_table.dart';
import 'xlsx_workbook.dart';

const List<String> spreadsheetFileExtensions = ['xlsx', 'xlsm', 'csv'];

class SpreadsheetReader {
  const SpreadsheetReader();

  static const String csvSheetName = 'CSV';

  Future<List<String>> readSheetNames(String path) {
    return Isolate.run(() => _readSheetNamesNow(path));
  }

  Future<SpreadsheetTable> readTable(String path, String sheetName) {
    return Isolate.run(() => _readTableNow(path, sheetName));
  }
}

Future<List<String>> _readSheetNamesNow(String path) async {
  if (_isCsv(path)) return const [SpreadsheetReader.csvSheetName];
  final workbook = XlsxWorkbook.decode(await _readExcelBytes(path));
  if (workbook.sheetNames.isEmpty) {
    throw const SpreadsheetReadException('This Excel file has no sheets.');
  }
  return workbook.sheetNames;
}

Future<SpreadsheetTable> _readTableNow(String path, String sheetName) async {
  if (_isCsv(path)) {
    return tableFromCells(
      SheetCells(cells: parseCsv(await _readCsvText(path))),
    );
  }
  final workbook = XlsxWorkbook.decode(await _readExcelBytes(path));
  return tableFromCells(workbook.readSheetCells(sheetName));
}

bool _isCsv(String path) => p.extension(path).toLowerCase() == '.csv';

Future<Uint8List> _readExcelBytes(String path) async {
  final extension = p.extension(path).toLowerCase();
  if (extension == '.xls') {
    throw const SpreadsheetReadException(
      'Old .xls files cannot be read. Open the file in Excel and use '
      'Save As → Excel Workbook (.xlsx).',
    );
  }
  if (extension != '.xlsx' && extension != '.xlsm') {
    throw const SpreadsheetReadException(
      'Please choose an Excel (.xlsx) or CSV (.csv) file.',
    );
  }
  return _readFileBytes(path);
}

Future<String> _readCsvText(String path) async {
  final bytes = await _readFileBytes(path);
  try {
    return utf8.decode(bytes).replaceFirst('\uFEFF', '');
  } on FormatException {
    return latin1.decode(bytes);
  }
}

Future<Uint8List> _readFileBytes(String path) async {
  try {
    return await File(path).readAsBytes();
  } on FileSystemException {
    throw SpreadsheetReadException(
      'Could not open "${p.basename(path)}". '
      'Check that the file exists and is not open in another program.',
    );
  }
}

SpreadsheetTable tableFromCells(SheetCells sheet) {
  final cells = sheet.cells;
  final headerRowIndex = cells.indexWhere(_hasAnyText);
  if (headerRowIndex < 0) return SpreadsheetTable.empty;
  final headers = _uniqueHeaders(cells[headerRowIndex]);
  final rows = <Map<String, String>>[];
  final excelRowNumbers = <int>[];
  var hiddenRowCount = 0;
  for (var index = headerRowIndex + 1; index < cells.length; index++) {
    final row = cells[index];
    if (!_hasAnyText(row)) continue;
    if (sheet.hiddenRowIndexes.contains(index)) {
      hiddenRowCount++;
      continue;
    }
    rows.add({
      for (var column = 0; column < headers.length; column++)
        headers[column]: column < row.length ? row[column].trim() : '',
    });
    excelRowNumbers.add(index + 1);
  }
  return SpreadsheetTable(
    headers: headers,
    rows: rows,
    excelRowNumbers: excelRowNumbers,
    hiddenRowCount: hiddenRowCount,
  );
}

bool _hasAnyText(List<String> row) => row.any((cell) => cell.trim().isNotEmpty);

List<String> _uniqueHeaders(List<String> headerCells) {
  final headers = <String>[];
  for (var column = 0; column < headerCells.length; column++) {
    final text = headerCells[column].trim();
    final base = text.isEmpty ? 'Column ${_columnLetters(column)}' : text;
    var header = base;
    var copyNumber = 2;
    while (headers.contains(header)) {
      header = '$base ($copyNumber)';
      copyNumber++;
    }
    headers.add(header);
  }
  return headers;
}

String _columnLetters(int columnIndex) {
  var index = columnIndex + 1;
  final letters = StringBuffer();
  while (index > 0) {
    final remainder = (index - 1) % 26;
    letters.write(String.fromCharCode(65 + remainder));
    index = (index - 1) ~/ 26;
  }
  return letters.toString().split('').reversed.join();
}

List<List<String>> parseCsv(String text) {
  final delimiter = _guessCsvDelimiter(text);
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var insideQuotes = false;
  for (var index = 0; index < text.length; index++) {
    final char = text[index];
    if (insideQuotes) {
      if (char == '"' && index + 1 < text.length && text[index + 1] == '"') {
        field.write('"');
        index++;
      } else if (char == '"') {
        insideQuotes = false;
      } else {
        field.write(char);
      }
    } else if (char == '"') {
      insideQuotes = true;
    } else if (char == delimiter) {
      row.add(field.toString());
      field.clear();
    } else if (char == '\n' || char == '\r') {
      if (char == '\r' && index + 1 < text.length && text[index + 1] == '\n') {
        index++;
      }
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(char);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

String _guessCsvDelimiter(String text) {
  final firstLine = text.split(RegExp(r'\r?\n')).first;
  const candidates = [',', ';', '\t'];
  var best = ',';
  var bestCount = 0;
  for (final candidate in candidates) {
    final count = candidate.allMatches(firstLine).length;
    if (count > bestCount) {
      best = candidate;
      bestCount = count;
    }
  }
  return best;
}
