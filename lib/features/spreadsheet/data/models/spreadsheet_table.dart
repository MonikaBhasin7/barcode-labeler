class SpreadsheetTable {
  const SpreadsheetTable({
    required this.headers,
    required this.rows,
    required this.excelRowNumbers,
    this.hiddenRowCount = 0,
  });

  static const SpreadsheetTable empty = SpreadsheetTable(
    headers: [],
    rows: [],
    excelRowNumbers: [],
  );

  final List<String> headers;
  final List<Map<String, String>> rows;
  final List<int> excelRowNumbers;
  final int hiddenRowCount;

  int get firstExcelRow => excelRowNumbers.isEmpty ? 0 : excelRowNumbers.first;

  int get lastExcelRow => excelRowNumbers.isEmpty ? 0 : excelRowNumbers.last;
}

class SheetCells {
  const SheetCells({required this.cells, this.hiddenRowIndexes = const {}});

  final List<List<String>> cells;
  final Set<int> hiddenRowIndexes;
}

class SpreadsheetReadException implements Exception {
  const SpreadsheetReadException(this.message);

  final String message;

  @override
  String toString() => message;
}
