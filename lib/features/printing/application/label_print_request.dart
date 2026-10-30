import 'dart:isolate';
import 'dart:typed_data';

import '../../../core/units.dart';
import '../../design/application/label_value_resolver.dart';
import '../../design/application/sheet_geometry.dart';
import '../../design/data/models/label_design.dart';
import '../../design/data/models/label_font.dart';
import '../../design/data/models/label_item.dart';
import '../data/models/printer_offset.dart';
import 'label_text_checker.dart';

const int _maxProblemsListed = 8;
const String nothingToPrintProblem = 'There is nothing to print yet.';

class FontFiles {
  const FontFiles({required this.regular, required this.bold});

  final Uint8List regular;
  final Uint8List bold;
}

class LabelFonts {
  const LabelFonts(this.filesByFont);

  final Map<TextFont, FontFiles> filesByFont;

  bool has(TextFont font) => filesByFont.containsKey(font);

  FontFiles filesFor(TextFont font) {
    return filesByFont[font] ?? filesByFont[robotoFont]!;
  }

  FontFiles get robotoFiles => filesFor(robotoFont);

  LabelFonts onlyFor(Set<TextFont> fonts) {
    return LabelFonts({
      for (final entry in filesByFont.entries)
        if (fonts.contains(entry.key) || entry.key == robotoFont)
          entry.key: entry.value,
    });
  }
}

class LabelPrintRequest {
  const LabelPrintRequest({
    required this.design,
    required this.records,
    required this.recordNumbers,
    required this.copiesPerRecord,
    required this.startAtPosition,
    required this.serialStarts,
    required this.typedAnswers,
    required this.offset,
    required this.today,
    required this.fonts,
    this.maxSheets,
  });

  final LabelDesign design;
  final List<Map<String, String>> records;
  final List<int> recordNumbers;
  final int copiesPerRecord;
  final int startAtPosition;
  final Map<String, int> serialStarts;
  final Map<String, String> typedAnswers;
  final PrinterOffset offset;
  final DateTime today;
  final LabelFonts fonts;
  final int? maxSheets;

  int get labelCount => records.length * copiesPerRecord;

  int get sheetCount {
    if (labelCount == 0) return 0;
    final perSheet = design.sheet.labelsPerSheet;
    return (startAtPosition - 1 + labelCount + perSheet - 1) ~/ perSheet;
  }

  LabelValueContext valueContextFor(int recordIndex) {
    return LabelValueContext(
      row: records[recordIndex],
      recordIndex: recordIndex,
      serialStarts: serialStarts,
      typedAnswers: typedAnswers,
      today: today,
    );
  }

  LabelPrintRequest limitedToSheets(int sheets) {
    return LabelPrintRequest(
      design: design,
      records: records,
      recordNumbers: recordNumbers,
      copiesPerRecord: copiesPerRecord,
      startAtPosition: startAtPosition,
      serialStarts: serialStarts,
      typedAnswers: typedAnswers,
      offset: offset,
      today: today,
      fonts: fonts,
      maxSheets: sheets,
    );
  }
}

Future<List<String>> findPrintProblemsInBackground(
  LabelPrintRequest request, {
  required List<String> availableColumns,
  LengthUnit unit = LengthUnit.mm,
}) {
  return Isolate.run(
    () => findPrintProblems(
      request,
      availableColumns: availableColumns,
      unit: unit,
    ),
  );
}

List<String> findPrintProblems(
  LabelPrintRequest request, {
  required List<String> availableColumns,
  LengthUnit unit = LengthUnit.mm,
}) {
  final sheetProblem = sheetLayoutProblem(request.design.sheet, unit: unit);
  final perSheet = request.design.sheet.labelsPerSheet;
  final unanswered = _unansweredQuestionProblems(request);
  return [
    ?sheetProblem,
    if (request.labelCount == 0) nothingToPrintProblem,
    if (request.copiesPerRecord < 1) 'Copies must be 1 or more.',
    if (request.startAtPosition < 1 || request.startAtPosition > perSheet)
      'Start at must be a label number from 1 to $perSheet.',
    ...unanswered,
    ..._missingColumnProblems(request.design, availableColumns),
    ..._missingFontProblems(request),
    if (unanswered.isEmpty) ..._valueProblems(request),
  ];
}

List<String> _unansweredQuestionProblems(LabelPrintRequest request) {
  return [
    for (final question in request.design.printQuestions)
      if ((request.typedAnswers[question.key] ?? '').trim().isEmpty)
        'Type the answer for "${question.prompt}".',
  ];
}

List<String> _missingColumnProblems(
  LabelDesign design,
  List<String> availableColumns,
) {
  return [
    for (final column in design.excelColumnsUsed)
      if (!availableColumns.contains(column))
        'The Excel sheet has no column named "$column".',
  ];
}

List<String> _missingFontProblems(LabelPrintRequest request) {
  return [
    for (final font in request.design.fontsUsed)
      if (!request.fonts.has(font))
        'The font "${font.name}" is not on this PC, or it cannot be printed. '
            'Install the font on this PC, or choose another font.',
  ];
}

List<String> _valueProblems(LabelPrintRequest request) {
  final checkedItems = request.design.items
      .where((item) => item is BarcodeItem || item is TextItem)
      .toList();
  if (checkedItems.isEmpty) return const [];
  final resolver = LabelValueResolver(request.design.items);
  final textChecker = LabelTextChecker(request.fonts);
  final problemByValue = <(String, String), String?>{};
  final problems = <String>[];
  var hiddenProblemCount = 0;
  for (var index = 0; index < request.records.length; index++) {
    final context = request.valueContextFor(index);
    for (final item in checkedItems) {
      final value = resolver.resolve(item, context);
      final problem = problemByValue.putIfAbsent((
        item.id,
        value,
      ), () => _problemWithValue(item, value, textChecker));
      if (problem == null) continue;
      if (problems.length < _maxProblemsListed) {
        problems.add(
          '${_recordLabel(request, index)}: ${item.name} "$value" $problem',
        );
      } else {
        hiddenProblemCount++;
      }
    }
  }
  if (hiddenProblemCount > 0) {
    problems.add('…and $hiddenProblemCount more problems like these.');
  }
  return problems;
}

String? _problemWithValue(
  LabelItem item,
  String value,
  LabelTextChecker textChecker,
) {
  return switch (item) {
    final BarcodeItem barcode => switch (barcode.type.problemWithValue(value)) {
      final problem? => 'cannot be this barcode. $problem',
      null => textChecker.problemWithBarcodeNumber(barcode, value),
    },
    final TextItem text => textChecker.problemWith(text, value),
    _ => null,
  };
}

String _recordLabel(LabelPrintRequest request, int recordIndex) {
  final number = request.recordNumbers[recordIndex];
  return request.design.usesExcelColumns
      ? 'Excel row $number'
      : 'Label $number';
}
