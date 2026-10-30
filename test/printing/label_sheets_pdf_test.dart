import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:barcode_labeler/features/design/data/models/label_design.dart';
import 'package:barcode_labeler/features/design/data/models/label_font.dart';
import 'package:barcode_labeler/features/design/data/models/label_item.dart';
import 'package:barcode_labeler/features/printing/application/label_print_request.dart';
import 'package:barcode_labeler/features/printing/application/label_sheets_pdf.dart';
import 'package:barcode_labeler/features/printing/data/models/printer_offset.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_designs.dart';

int pageCountOf(Uint8List pdf) {
  final text = latin1.decode(pdf);
  return RegExp(r'/Type\s*/Page(?![s])').allMatches(text).length;
}

void writeSampleWhenAsked(String name, Uint8List pdf) {
  final folder = Platform.environment['LABEL_PDF_SAMPLE_DIR'];
  if (folder == null) return;
  File('$folder/$name').writeAsBytesSync(pdf);
}

void main() {
  test('builds one page per sheet of labels', () async {
    final pdf = await buildLabelSheetsPdf(
      stockPrintRequest(startAtPosition: 2),
    );
    writeSampleWhenAsked('stock_labels.pdf', pdf);

    expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
    expect(pageCountOf(pdf), 2);
  });

  test('builds the same PDF in a background isolate', () async {
    final pdf = await buildLabelSheetsPdfInBackground(stockPrintRequest());

    expect(pageCountOf(pdf), 2);
  });

  test('a preview can stop after the first sheets', () async {
    final request = stockPrintRequest(copiesPerRecord: 3).limitedToSheets(1);

    final pdf = await buildLabelSheetsPdf(request);

    expect(pageCountOf(pdf), 1);
  });

  test('the alignment test sheet is a single page', () async {
    final pdf = await buildAlignmentTestPdf(
      sheet: sixLabelSheet,
      offset: const PrinterOffset(rightMm: 1, downMm: -0.5),
      regularFont: readBundledFonts().robotoFiles.regular,
    );
    writeSampleWhenAsked('alignment_test.pdf', pdf);

    expect(pageCountOf(pdf), 1);
  });

  test('the page is the exact paper size', () {
    final format = pageFormatOf(SheetLayout.wholeA4Page);

    expect(format.width, closeTo(595.28, 0.01));
    expect(format.height, closeTo(841.89, 0.01));
  });

  test('only the fonts a design uses go into the print job', () {
    final fonts = readBundledFonts().onlyFor(stockLabelDesign.fontsUsed);

    expect(fonts.filesByFont.keys.toSet(), {
      robotoFont,
      const BuiltInFont(LabelFont.robotoCondensed),
    });
  });

  test('text in a font from this PC is printed with that font', () async {
    final lato = File(LabelFont.lato.regularAsset).readAsBytesSync();
    const latoFromPc = InstalledFont('Lato from this PC');
    final design = stockLabelDesign.copyWith(
      items: [
        for (final item in stockLabelDesign.items)
          item is TextItem ? item.copyWith(font: latoFromPc) : item,
      ],
    );
    final request = stockPrintRequest();
    final fonts = LabelFonts({
      ...request.fonts.filesByFont,
      latoFromPc: FontFiles(regular: lato, bold: lato),
    });

    final pdf = await buildLabelSheetsPdf(
      LabelPrintRequest(
        design: design,
        records: request.records,
        recordNumbers: request.recordNumbers,
        copiesPerRecord: 1,
        startAtPosition: 1,
        serialStarts: const {},
        typedAnswers: const {},
        offset: PrinterOffset.none,
        today: request.today,
        fonts: fonts.onlyFor(design.fontsUsed),
      ),
    );

    expect(latin1.decode(pdf), contains('Lato-Regular'));
    expect(latin1.decode(pdf), isNot(contains('RobotoCondensed')));
  });

  test('the number under a barcode is printed in its own font', () async {
    final design = stockLabelDesign.copyWith(
      items: [
        for (final item in stockLabelDesign.items)
          item is BarcodeItem
              ? item.copyWith(numberFont: const BuiltInFont(LabelFont.tinos))
              : item,
      ],
    );
    final request = stockPrintRequest();

    final pdf = await buildLabelSheetsPdf(
      LabelPrintRequest(
        design: design,
        records: request.records,
        recordNumbers: request.recordNumbers,
        copiesPerRecord: 1,
        startAtPosition: 1,
        serialStarts: const {},
        typedAnswers: const {},
        offset: PrinterOffset.none,
        today: request.today,
        fonts: request.fonts.onlyFor(design.fontsUsed),
      ),
    );

    expect(latin1.decode(pdf), contains('Tinos-Regular'));
  });
}
