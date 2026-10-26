import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/units.dart';
import '../../design/application/label_value_resolver.dart';
import '../../design/application/sheet_geometry.dart';
import '../../design/data/models/label_design.dart';
import '../../design/data/models/label_item.dart';
import '../data/models/printer_offset.dart';
import 'label_print_request.dart';

const double barcodeTextGapMm = 0.5;

PdfPageFormat pageFormatOf(SheetLayout sheet) {
  return PdfPageFormat(
    sheet.pageWidthMm * pointsPerMm,
    sheet.pageHeightMm * pointsPerMm,
  );
}

Future<Uint8List> buildLabelSheetsPdf(LabelPrintRequest request) async {
  final document = pw.Document(
    title: request.design.name,
    creator: 'Barcode Labeler',
  );
  final drawing = _LabelDrawing.from(request);
  for (final labels in _labelsGroupedBySheet(request, drawing)) {
    document.addPage(_sheetPage(request.design.sheet, labels));
  }
  return document.save();
}

Future<Uint8List> buildLabelSheetsPdfInBackground(LabelPrintRequest request) {
  return Isolate.run(() => buildLabelSheetsPdf(request));
}

Future<Uint8List> buildAlignmentTestPdf({
  required SheetLayout sheet,
  required PrinterOffset offset,
  required Uint8List regularFont,
}) async {
  final font = pw.Font.ttf(ByteData.sublistView(regularFont));
  final document = pw.Document(title: 'Alignment test sheet');
  final outlines = [
    for (final (index, slot) in labelSlotsInFillOrder(sheet).indexed)
      _labelOutline(sheet, slot, offset, index + 1, font),
  ];
  document.addPage(
    _sheetPage(sheet, [...outlines, _hundredMmRuler(sheet, font)]),
  );
  return document.save();
}

List<List<pw.Widget>> _labelsGroupedBySheet(
  LabelPrintRequest request,
  _LabelDrawing drawing,
) {
  final slots = labelSlotsInFillOrder(request.design.sheet);
  final sheetCount = math.min(
    request.sheetCount,
    request.maxSheets ?? request.sheetCount,
  );
  final sheets = List.generate(sheetCount, (_) => <pw.Widget>[]);
  var position = request.startAtPosition - 1;
  for (var index = 0; index < request.records.length; index++) {
    final values = drawing.valuesFor(request.valueContextFor(index));
    for (var copy = 0; copy < request.copiesPerRecord; copy++) {
      final sheetIndex = position ~/ slots.length;
      if (sheetIndex >= sheetCount) return sheets;
      final slot = slots[position % slots.length];
      sheets[sheetIndex].add(drawing.positionedLabel(slot, values));
      position++;
    }
  }
  return sheets;
}

pw.Page _sheetPage(SheetLayout sheet, List<pw.Widget> children) {
  return pw.Page(
    pageFormat: pageFormatOf(sheet),
    margin: pw.EdgeInsets.zero,
    build: (_) => pw.Stack(
      children: [
        pw.SizedBox(
          width: sheet.pageWidthMm * pointsPerMm,
          height: sheet.pageHeightMm * pointsPerMm,
        ),
        ...children,
      ],
    ),
  );
}

pw.Widget _labelOutline(
  SheetLayout sheet,
  LabelSlot slot,
  PrinterOffset offset,
  int labelNumber,
  pw.Font font,
) {
  final heightPt = sheet.labelHeightMm * pointsPerMm;
  return pw.Positioned(
    left: (slot.leftMm + offset.rightMm) * pointsPerMm,
    top: (slot.topMm + offset.downMm) * pointsPerMm,
    child: pw.Container(
      width: sheet.labelWidthMm * pointsPerMm,
      height: heightPt,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: pw.Text(
        '$labelNumber',
        style: pw.TextStyle(font: font, fontSize: math.min(12, heightPt * 0.4)),
      ),
    ),
  );
}

pw.Widget _hundredMmRuler(SheetLayout sheet, pw.Font font) {
  final lengthPt = 100 * pointsPerMm;
  return pw.Positioned(
    left: (sheet.pageWidthMm - 100) / 2 * pointsPerMm,
    top: (sheet.pageHeightMm / 2 - 6) * pointsPerMm,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'This line must measure exactly 100 mm',
          style: pw.TextStyle(font: font, fontSize: 8),
        ),
        pw.SizedBox(height: 2),
        pw.CustomPaint(
          size: PdfPoint(lengthPt, 4 * pointsPerMm),
          painter: (canvas, size) => _paintRulerTicks(canvas, size),
        ),
      ],
    ),
  );
}

void _paintRulerTicks(PdfGraphics canvas, PdfPoint size) {
  canvas
    ..setStrokeColor(PdfColors.black)
    ..setLineWidth(0.5)
    ..moveTo(0, 0)
    ..lineTo(size.x, 0);
  for (var mm = 0; mm <= 100; mm += 10) {
    final x = mm * pointsPerMm;
    canvas
      ..moveTo(x, 0)
      ..lineTo(x, size.y);
  }
  canvas.strokePath();
}

class _LabelDrawing {
  _LabelDrawing._({
    required this.design,
    required this.offset,
    required this.regularFont,
    required this.boldFont,
    required this.pictures,
    required this.resolver,
  });

  factory _LabelDrawing.from(LabelPrintRequest request) {
    return _LabelDrawing._(
      design: request.design,
      offset: request.offset,
      regularFont: pw.Font.ttf(ByteData.sublistView(request.fonts.regular)),
      boldFont: pw.Font.ttf(ByteData.sublistView(request.fonts.bold)),
      pictures: {
        for (final item in request.design.items.whereType<PictureItem>())
          item.id: pw.MemoryImage(item.imageBytes),
      },
      resolver: LabelValueResolver(request.design.items),
    );
  }

  final LabelDesign design;
  final PrinterOffset offset;
  final pw.Font regularFont;
  final pw.Font boldFont;
  final Map<String, pw.MemoryImage> pictures;
  final LabelValueResolver resolver;

  Map<String, String> valuesFor(LabelValueContext context) {
    return {
      for (final item in design.items)
        if (item.labelValue != null) item.id: resolver.resolve(item, context),
    };
  }

  pw.Widget positionedLabel(LabelSlot slot, Map<String, String> values) {
    final sheet = design.sheet;
    return pw.Positioned(
      left: (slot.leftMm + offset.rightMm) * pointsPerMm,
      top: (slot.topMm + offset.downMm) * pointsPerMm,
      child: pw.Stack(
        children: [
          pw.SizedBox(
            width: sheet.labelWidthMm * pointsPerMm,
            height: sheet.labelHeightMm * pointsPerMm,
          ),
          for (final item in design.items)
            _positionedItem(item, values[item.id] ?? ''),
        ],
      ),
    );
  }

  pw.Widget _positionedItem(LabelItem item, String value) {
    final widthPt = item.frame.width * pointsPerMm;
    final heightPt = item.frame.height * pointsPerMm;
    return pw.Positioned(
      left: item.frame.x * pointsPerMm,
      top: item.frame.y * pointsPerMm,
      child: pw.ClipRect(
        child: pw.SizedBox(
          width: widthPt,
          height: heightPt,
          child: _rotated(
            item.rotation,
            widthPt,
            heightPt,
            (width, height) => _itemContent(item, value, width, height),
          ),
        ),
      ),
    );
  }

  pw.Widget _itemContent(
    LabelItem item,
    String value,
    double width,
    double height,
  ) {
    return switch (item) {
      TextItem() => _textContent(item, value, width, height),
      BarcodeItem() => _barcodeContent(item, value, width, height),
      ShapeItem() => _shapeContent(item, width, height),
      PictureItem() => _pictureContent(item, width, height),
    };
  }

  pw.Widget _textContent(
    TextItem item,
    String value,
    double width,
    double height,
  ) {
    return pw.Container(
      width: width,
      height: height,
      alignment: switch (item.alignment) {
        TextAlignment.left => pw.Alignment.centerLeft,
        TextAlignment.center => pw.Alignment.center,
        TextAlignment.right => pw.Alignment.centerRight,
      },
      child: pw.Text(
        value,
        textAlign: switch (item.alignment) {
          TextAlignment.left => pw.TextAlign.left,
          TextAlignment.center => pw.TextAlign.center,
          TextAlignment.right => pw.TextAlign.right,
        },
        style: pw.TextStyle(
          font: item.bold ? boldFont : regularFont,
          fontSize: item.fontSizePt,
          color: PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget _barcodeContent(
    BarcodeItem item,
    String value,
    double width,
    double height,
  ) {
    if (item.type.problemWithValue(value) != null) {
      return _wrongBarcodeValueMark(width, height);
    }
    if (item.type.isSquare) {
      final side = math.min(width, height);
      return pw.Container(
        width: width,
        height: height,
        alignment: pw.Alignment.center,
        child: pw.BarcodeWidget(
          barcode: item.type.barcode,
          data: value,
          width: side,
          height: side,
          drawText: false,
        ),
      );
    }
    return pw.BarcodeWidget(
      barcode: item.type.barcode,
      data: value,
      width: width,
      height: height,
      drawText: item.drawsTextUnderBars,
      textStyle: pw.TextStyle(font: regularFont, fontSize: item.textSizePt),
      textPadding: barcodeTextGapMm * pointsPerMm,
    );
  }

  pw.Widget _wrongBarcodeValueMark(double width, double height) {
    return pw.Container(
      width: width,
      height: height,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.red, width: 1),
      ),
      child: pw.Text(
        'Wrong value',
        style: pw.TextStyle(
          font: regularFont,
          fontSize: 6,
          color: PdfColors.red,
        ),
      ),
    );
  }

  pw.Widget _shapeContent(ShapeItem item, double width, double height) {
    return pw.CustomPaint(
      size: PdfPoint(width, height),
      painter: (canvas, size) =>
          _paintShape(canvas, size, item, item.lineWidthMm * pointsPerMm),
    );
  }

  pw.Widget _pictureContent(PictureItem item, double width, double height) {
    return pw.Image(
      pictures[item.id]!,
      width: width,
      height: height,
      fit: pw.BoxFit.contain,
    );
  }
}

pw.Widget _rotated(
  QuarterTurn rotation,
  double frameWidth,
  double frameHeight,
  pw.Widget Function(double width, double height) buildContent,
) {
  if (rotation == QuarterTurn.none) {
    return buildContent(frameWidth, frameHeight);
  }
  final contentWidth = rotation.swapsWidthAndHeight ? frameHeight : frameWidth;
  final contentHeight = rotation.swapsWidthAndHeight ? frameWidth : frameHeight;
  return pw.Transform.rotateBox(
    angle: -rotation.turns * math.pi / 2,
    unconstrained: true,
    child: pw.SizedBox(
      width: contentWidth,
      height: contentHeight,
      child: buildContent(contentWidth, contentHeight),
    ),
  );
}

void _paintShape(
  PdfGraphics canvas,
  PdfPoint size,
  ShapeItem item,
  double lineWidth,
) {
  canvas
    ..setStrokeColor(PdfColors.black)
    ..setFillColor(PdfColors.black)
    ..setLineWidth(lineWidth);
  switch (item.shape) {
    case ShapeKind.line:
      _paintLineAlongLongerSide(canvas, size);
      canvas.strokePath();
    case ShapeKind.rectangle when item.filled:
      canvas
        ..drawRect(0, 0, size.x, size.y)
        ..fillPath();
    case ShapeKind.rectangle:
      canvas
        ..drawRect(
          lineWidth / 2,
          lineWidth / 2,
          size.x - lineWidth,
          size.y - lineWidth,
        )
        ..strokePath();
    case ShapeKind.ellipse when item.filled:
      canvas
        ..drawEllipse(size.x / 2, size.y / 2, size.x / 2, size.y / 2)
        ..fillPath();
    case ShapeKind.ellipse:
      canvas
        ..drawEllipse(
          size.x / 2,
          size.y / 2,
          size.x / 2 - lineWidth / 2,
          size.y / 2 - lineWidth / 2,
        )
        ..strokePath();
  }
}

void _paintLineAlongLongerSide(PdfGraphics canvas, PdfPoint size) {
  if (size.x >= size.y) {
    canvas
      ..moveTo(0, size.y / 2)
      ..lineTo(size.x, size.y / 2);
  } else {
    canvas
      ..moveTo(size.x / 2, 0)
      ..lineTo(size.x / 2, size.y);
  }
}
