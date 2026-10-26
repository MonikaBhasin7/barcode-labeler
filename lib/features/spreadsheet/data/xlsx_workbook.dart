import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import 'excel_number_format.dart';
import 'models/spreadsheet_table.dart';

const Map<int, String> _builtInFormatCodes = {
  0: 'General',
  1: '0',
  2: '0.00',
  3: '#,##0',
  4: '#,##0.00',
  9: '0%',
  10: '0.00%',
  14: 'dd/mm/yyyy',
  15: 'd-mmm-yy',
  16: 'd-mmm',
  17: 'mmm-yy',
  18: 'h:mm AM/PM',
  19: 'h:mm:ss AM/PM',
  20: 'h:mm',
  21: 'h:mm:ss',
  22: 'dd/mm/yyyy h:mm',
  45: 'mm:ss',
  46: 'h:mm:ss',
  47: 'mm:ss',
  49: '@',
};

const Set<int> _otherBuiltInDateFormatIds = {
  27,
  28,
  29,
  30,
  31,
  32,
  33,
  34,
  35,
  36,
  50,
  51,
  52,
  53,
  54,
  55,
  56,
  57,
  58,
};

class XlsxWorkbook {
  XlsxWorkbook._({
    required Archive archive,
    required Map<String, String> sheetPathsByName,
    required List<String> sharedStrings,
    required List<String> formatCodeByStyle,
    required bool usesDate1904,
  }) : _archive = archive,
       _sheetPathsByName = sheetPathsByName,
       _sharedStrings = sharedStrings,
       _formatCodeByStyle = formatCodeByStyle,
       _usesDate1904 = usesDate1904;

  factory XlsxWorkbook.decode(Uint8List bytes) {
    final archive = _unzip(bytes);
    final workbook = _parseXml(archive, 'xl/workbook.xml');
    if (workbook == null) {
      throw const SpreadsheetReadException(
        'This file is not a readable .xlsx Excel file.',
      );
    }
    return XlsxWorkbook._(
      archive: archive,
      sheetPathsByName: _readSheetPaths(archive, workbook),
      sharedStrings: _readSharedStrings(archive),
      formatCodeByStyle: _readFormatCodeByStyle(archive),
      usesDate1904: _readUsesDate1904(workbook),
    );
  }

  final Archive _archive;
  final Map<String, String> _sheetPathsByName;
  final List<String> _sharedStrings;
  final List<String> _formatCodeByStyle;
  final bool _usesDate1904;

  List<String> get sheetNames => _sheetPathsByName.keys.toList();

  SheetCells readSheetCells(String sheetName) {
    final path = _sheetPathsByName[sheetName];
    final sheet = path == null ? null : _parseXml(_archive, path);
    if (sheet == null) {
      throw SpreadsheetReadException('Sheet "$sheetName" was not found.');
    }
    final cellsByRow = <int, Map<int, String>>{};
    final hiddenRowIndexes = <int>{};
    var nextRowIndex = 0;
    for (final row in _descendantsNamed(sheet, 'row')) {
      final rowIndex = _rowIndexOf(row) ?? nextRowIndex;
      nextRowIndex = rowIndex + 1;
      if (_isHidden(row)) hiddenRowIndexes.add(rowIndex);
      final cells = _readRowCells(row);
      if (cells.isNotEmpty) cellsByRow[rowIndex] = cells;
    }
    return SheetCells(
      cells: _cellsAsGrid(cellsByRow),
      hiddenRowIndexes: hiddenRowIndexes,
    );
  }

  Map<int, String> _readRowCells(XmlElement row) {
    final cells = <int, String>{};
    var nextColumnIndex = 0;
    for (final cell in _childrenNamed(row, 'c')) {
      final columnIndex = _columnIndexOf(cell) ?? nextColumnIndex;
      nextColumnIndex = columnIndex + 1;
      final text = _cellDisplayText(cell);
      if (text.trim().isNotEmpty) cells[columnIndex] = text;
    }
    return cells;
  }

  String _cellDisplayText(XmlElement cell) {
    final rawValue = _childrenNamed(cell, 'v').firstOrNull?.innerText ?? '';
    return switch (cell.getAttribute('t')) {
      's' => _sharedStringAt(rawValue),
      'inlineStr' => _textOfRuns(cell),
      'b' => rawValue == '1' ? 'TRUE' : 'FALSE',
      'str' || 'e' => decodeExcelEscapes(rawValue),
      'd' => _isoDateText(rawValue),
      _ => excelCellText(
        rawValue,
        _formatCodeOf(cell),
        usesDate1904: _usesDate1904,
      ),
    };
  }

  String _sharedStringAt(String rawIndex) {
    final index = int.tryParse(rawIndex);
    if (index == null || index < 0 || index >= _sharedStrings.length) {
      return '';
    }
    return _sharedStrings[index];
  }

  String _formatCodeOf(XmlElement cell) {
    final styleIndex = int.tryParse(cell.getAttribute('s') ?? '');
    if (styleIndex == null || styleIndex >= _formatCodeByStyle.length) {
      return 'General';
    }
    return _formatCodeByStyle[styleIndex];
  }

  String _isoDateText(String rawValue) {
    final moment = DateTime.tryParse(rawValue);
    return moment == null ? rawValue : DateFormat('dd/MM/yyyy').format(moment);
  }
}

Archive _unzip(Uint8List bytes) {
  try {
    return ZipDecoder().decodeBytes(bytes);
  } on Object {
    throw const SpreadsheetReadException(
      'This file is not a readable .xlsx Excel file. '
      'If it has a password, remove the password and try again.',
    );
  }
}

XmlDocument? _parseXml(Archive archive, String path) {
  final file = archive.findFile(path);
  if (file == null) return null;
  try {
    return XmlDocument.parse(utf8.decode(file.content, allowMalformed: true));
  } on XmlException {
    throw SpreadsheetReadException('Part of the Excel file is damaged: $path');
  }
}

Map<String, String> _readSheetPaths(Archive archive, XmlDocument workbook) {
  final targetsById = <String, String>{};
  final relations = _parseXml(archive, 'xl/_rels/workbook.xml.rels');
  if (relations != null) {
    for (final relation in _descendantsNamed(relations, 'Relationship')) {
      final id = relation.getAttribute('Id');
      final target = relation.getAttribute('Target');
      if (id != null && target != null) targetsById[id] = target;
    }
  }
  final pathsByName = <String, String>{};
  for (final sheet in _descendantsNamed(workbook, 'sheet')) {
    final name = sheet.getAttribute('name');
    final target = targetsById[_relationIdOf(sheet)];
    if (name != null && target != null) {
      pathsByName[name] = _archivePathOf(target);
    }
  }
  return pathsByName;
}

String? _relationIdOf(XmlElement sheet) {
  for (final attribute in sheet.attributes) {
    if (attribute.name.local == 'id' && attribute.name.prefix != null) {
      return attribute.value;
    }
  }
  return null;
}

String _archivePathOf(String target) {
  if (target.startsWith('/')) return target.substring(1);
  return 'xl/$target';
}

List<String> _readSharedStrings(Archive archive) {
  final document = _parseXml(archive, 'xl/sharedStrings.xml');
  if (document == null) return const [];
  return [
    for (final item in _descendantsNamed(document, 'si')) _textOfRuns(item),
  ];
}

String _textOfRuns(XmlElement element) {
  final buffer = StringBuffer();
  for (final text in _descendantsNamed(element, 't')) {
    if (!_isPhoneticHint(text, element)) buffer.write(text.innerText);
  }
  return decodeExcelEscapes(buffer.toString());
}

bool _isPhoneticHint(XmlElement text, XmlElement stopAt) {
  XmlNode? node = text.parent;
  while (node != null && node != stopAt) {
    if (node is XmlElement && node.name.local == 'rPh') return true;
    node = node.parent;
  }
  return false;
}

List<String> _readFormatCodeByStyle(Archive archive) {
  final styles = _parseXml(archive, 'xl/styles.xml');
  if (styles == null) return const [];
  final customCodes = <int, String>{
    for (final format in _descendantsNamed(styles, 'numFmt'))
      ?int.tryParse(format.getAttribute('numFmtId') ?? ''):
          format.getAttribute('formatCode') ?? 'General',
  };
  final cellFormats = _descendantsNamed(styles, 'cellXfs').firstOrNull;
  if (cellFormats == null) return const [];
  return [
    for (final format in _childrenNamed(cellFormats, 'xf'))
      _formatCodeForId(
        int.tryParse(format.getAttribute('numFmtId') ?? '') ?? 0,
        customCodes,
      ),
  ];
}

String _formatCodeForId(int id, Map<int, String> customCodes) {
  if (customCodes[id] case final code?) return code;
  if (_otherBuiltInDateFormatIds.contains(id)) return 'dd/mm/yyyy';
  return _builtInFormatCodes[id] ?? 'General';
}

bool _readUsesDate1904(XmlDocument workbook) {
  final properties = _descendantsNamed(workbook, 'workbookPr').firstOrNull;
  final value = properties?.getAttribute('date1904');
  return value == '1' || value == 'true';
}

bool _isHidden(XmlElement row) {
  final hidden = row.getAttribute('hidden');
  return hidden == '1' || hidden == 'true';
}

int? _rowIndexOf(XmlElement row) {
  final number = int.tryParse(row.getAttribute('r') ?? '');
  return number == null ? null : number - 1;
}

int? _columnIndexOf(XmlElement cell) {
  final reference = cell.getAttribute('r');
  if (reference == null) return null;
  final letters = RegExp(r'^[A-Za-z]+').firstMatch(reference)?.group(0);
  if (letters == null) return null;
  var index = 0;
  for (final code in letters.toUpperCase().codeUnits) {
    index = index * 26 + (code - 64);
  }
  return index - 1;
}

List<List<String>> _cellsAsGrid(Map<int, Map<int, String>> cellsByRow) {
  if (cellsByRow.isEmpty) return const [];
  final lastRow = cellsByRow.keys.reduce((a, b) => a > b ? a : b);
  var lastColumn = -1;
  for (final cells in cellsByRow.values) {
    for (final column in cells.keys) {
      if (column > lastColumn) lastColumn = column;
    }
  }
  return [
    for (var row = 0; row <= lastRow; row++)
      [
        for (var column = 0; column <= lastColumn; column++)
          cellsByRow[row]?[column] ?? '',
      ],
  ];
}

Iterable<XmlElement> _descendantsNamed(XmlNode node, String localName) {
  return node.descendants.whereType<XmlElement>().where(
    (element) => element.name.local == localName,
  );
}

Iterable<XmlElement> _childrenNamed(XmlElement element, String localName) {
  return element.childElements.where((child) => child.name.local == localName);
}
