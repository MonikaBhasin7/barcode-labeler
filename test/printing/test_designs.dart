import 'dart:io';

import 'package:barcode_labeler/features/design/data/models/barcode_type.dart';
import 'package:barcode_labeler/features/design/data/models/label_design.dart';
import 'package:barcode_labeler/features/design/data/models/label_font.dart';
import 'package:barcode_labeler/features/design/data/models/label_item.dart';
import 'package:barcode_labeler/features/design/data/models/label_value.dart';
import 'package:barcode_labeler/features/printing/application/label_print_request.dart';
import 'package:barcode_labeler/features/printing/data/models/printer_offset.dart';

LabelFonts readBundledFonts() {
  return LabelFonts({
    for (final font in LabelFont.values)
      font: FontFiles(
        regular: File(font.regularAsset).readAsBytesSync(),
        bold: File(font.boldAsset).readAsBytesSync(),
      ),
  });
}

const SheetLayout sixLabelSheet = SheetLayout(
  paper: PaperSize.a4,
  pageWidthMm: 210,
  pageHeightMm: 297,
  marginTopMm: 15,
  marginLeftMm: 10,
  labelWidthMm: 90,
  labelHeightMm: 50,
  gapAcrossMm: 10,
  gapDownMm: 10,
  columns: 2,
  rows: 3,
);

const LabelDesign stockLabelDesign = LabelDesign(
  id: 'stock-design',
  name: 'Stock label',
  sheet: sixLabelSheet,
  items: [
    TextItem(
      id: 'name',
      name: 'Name',
      frame: ItemFrame(x: 4, y: 3, width: 60, height: 8),
      value: LabelValue(kind: ValueSourceKind.excelColumn, excelColumn: 'Name'),
      fontSizePt: 12,
      bold: true,
    ),
    BarcodeItem(
      id: 'code',
      name: 'Barcode 1',
      frame: ItemFrame(x: 4, y: 13, width: 60, height: 20),
      value: LabelValue(kind: ValueSourceKind.excelColumn, excelColumn: 'Code'),
    ),
    BarcodeItem(
      id: 'serial',
      name: 'Serial',
      frame: ItemFrame(x: 70, y: 3, width: 14, height: 44),
      rotation: QuarterTurn.quarter,
      value: LabelValue(
        kind: ValueSourceKind.serialNumber,
        serial: SerialNumberRule(start: 1000001),
      ),
      textSizePt: 7,
    ),
    BarcodeItem(
      id: 'qr',
      name: 'QR',
      frame: ItemFrame(x: 48, y: 34, width: 14, height: 14),
      type: BarcodeType.qrCode,
      value: LabelValue(kind: ValueSourceKind.sameAsItem, sameAsItemId: 'code'),
    ),
    TextItem(
      id: 'date',
      name: 'Date',
      frame: ItemFrame(x: 4, y: 38, width: 40, height: 8),
      value: LabelValue(kind: ValueSourceKind.date, prefix: 'Packed '),
      font: LabelFont.robotoCondensed,
      fontSizePt: 8,
    ),
    ShapeItem(
      id: 'border',
      name: 'Border',
      frame: ItemFrame(x: 0.5, y: 0.5, width: 89, height: 49),
      lineWidthMm: 0.4,
    ),
    ShapeItem(
      id: 'line',
      name: 'Line',
      frame: ItemFrame(x: 4, y: 34, width: 40, height: 2),
      shape: ShapeKind.line,
    ),
  ],
);

LabelPrintRequest stockPrintRequest({
  List<Map<String, String>>? records,
  int startAtPosition = 1,
  int copiesPerRecord = 1,
}) {
  return LabelPrintRequest(
    design: stockLabelDesign,
    records:
        records ??
        [
          for (var i = 1; i <= 8; i++)
            {'Name': 'Shirt size $i', 'Code': 'SKU-${1000 + i}'},
        ],
    recordNumbers: [
      for (var number = 1; number <= (records?.length ?? 8); number++) number,
    ],
    copiesPerRecord: copiesPerRecord,
    startAtPosition: startAtPosition,
    serialStarts: const {},
    typedAnswers: const {},
    offset: PrinterOffset.none,
    today: DateTime(2026, 10, 26),
    fonts: readBundledFonts(),
  );
}
