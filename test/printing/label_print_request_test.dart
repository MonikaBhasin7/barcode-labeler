import 'package:barcode_labeler/features/design/data/models/barcode_type.dart';
import 'package:barcode_labeler/features/design/data/models/label_item.dart';
import 'package:barcode_labeler/features/design/data/models/label_value.dart';
import 'package:barcode_labeler/features/printing/application/label_print_request.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_designs.dart';

void main() {
  test('counts labels and sheets, starting part way into a sheet', () {
    final request = stockPrintRequest(startAtPosition: 5, copiesPerRecord: 2);

    expect(request.labelCount, 16);
    expect(request.sheetCount, 4);
  });

  test('a ready request has no problems', () {
    final problems = findPrintProblems(
      stockPrintRequest(),
      availableColumns: const ['Name', 'Code'],
    );

    expect(problems, isEmpty);
  });

  test('a column missing from the Excel sheet is reported', () {
    final problems = findPrintProblems(
      stockPrintRequest(),
      availableColumns: const ['Name'],
    );

    expect(problems, contains('The Excel sheet has no column named "Code".'));
  });

  test('a value that cannot be a barcode names its real row', () {
    final request = stockPrintRequest();
    final eanDesign = request.design.copyWith(
      items: [
        for (final item in request.design.items)
          if (item is BarcodeItem && item.id == 'code')
            item.copyWith(type: BarcodeType.ean13)
          else
            item,
      ],
    );
    final eanRequest = LabelPrintRequest(
      design: eanDesign,
      records: request.records.sublist(2, 4),
      recordNumbers: const [3, 7],
      copiesPerRecord: 1,
      startAtPosition: 1,
      serialStarts: const {},
      typedAnswers: const {},
      offset: request.offset,
      today: request.today,
      fonts: request.fonts,
    );

    final problems = findPrintProblems(
      eanRequest,
      availableColumns: const ['Name', 'Code'],
    );

    expect(problems[0], startsWith('Excel row 3: Barcode 1 "SKU-1003"'));
    expect(problems[1], startsWith('Excel row 7: Barcode 1 "SKU-1004"'));
  });

  test('start at must be inside the sheet', () {
    final problems = findPrintProblems(
      stockPrintRequest(startAtPosition: 7),
      availableColumns: const ['Name', 'Code'],
    );

    expect(problems, contains('Start at must be a label number from 1 to 6.'));
  });

  test('a question without an answer stops printing', () {
    final request = stockPrintRequest();
    final askingDesign = request.design.copyWith(
      items: [
        ...request.design.items,
        const TextItem(
          id: 'batch',
          name: 'Batch',
          frame: ItemFrame(x: 1, y: 1, width: 20, height: 5),
          value: LabelValue(
            kind: ValueSourceKind.typedWhenPrinting,
            question: 'Batch number?',
          ),
        ),
      ],
    );
    LabelPrintRequest withAnswers(Map<String, String> answers) {
      return LabelPrintRequest(
        design: askingDesign,
        records: request.records,
        recordNumbers: request.recordNumbers,
        copiesPerRecord: 1,
        startAtPosition: 1,
        serialStarts: const {},
        typedAnswers: answers,
        offset: request.offset,
        today: request.today,
        fonts: request.fonts,
      );
    }

    final unanswered = findPrintProblems(
      withAnswers(const {}),
      availableColumns: const ['Name', 'Code'],
    );
    final answered = findPrintProblems(
      withAnswers(const {'batch': 'B-17'}),
      availableColumns: const ['Name', 'Code'],
    );

    expect(unanswered, ['Type the answer for "Batch number?".']);
    expect(answered, isEmpty);
  });
}
