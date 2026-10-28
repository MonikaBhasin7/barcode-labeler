import 'dart:math' as math;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../../../core/units.dart';
import '../../../design/data/models/label_item.dart';
import '../../../printing/application/label_sheets_pdf.dart';

class LabelItemView extends StatelessWidget {
  const LabelItemView({
    super.key,
    required this.item,
    required this.value,
    required this.pixelsPerMm,
  });

  final LabelItem item;
  final String value;
  final double pixelsPerMm;

  double _pointsToPixels(double points) => points * mmPerPoint * pixelsPerMm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: item.frame.width * pixelsPerMm,
      height: item.frame.height * pixelsPerMm,
      child: RotatedBox(
        quarterTurns: item.rotation.turns,
        child: switch (item) {
          final TextItem text => _textContent(text),
          final BarcodeItem barcode => _barcodeContent(barcode),
          final ShapeItem shape => CustomPaint(
            painter: _ShapePainter(shape, shape.lineWidthMm * pixelsPerMm),
          ),
          final PictureItem picture => Image(
            image: MemoryImage(picture.imageBytes),
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        },
      ),
    );
  }

  Widget _textContent(TextItem text) {
    return Align(
      alignment: switch (text.alignment) {
        TextAlignment.left => Alignment.centerLeft,
        TextAlignment.center => Alignment.center,
        TextAlignment.right => Alignment.centerRight,
      },
      child: Text(
        value,
        textAlign: switch (text.alignment) {
          TextAlignment.left => TextAlign.left,
          TextAlignment.center => TextAlign.center,
          TextAlignment.right => TextAlign.right,
        },
        style: TextStyle(
          fontFamily: text.font.familyName,
          fontSize: _pointsToPixels(text.fontSizePt),
          fontWeight: text.bold ? FontWeight.w700 : FontWeight.w400,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _barcodeContent(BarcodeItem barcode) {
    final problem = barcode.type.problemWithValue(value);
    if (problem != null) return _WrongBarcodeValue(problem: problem);
    if (barcode.type.isSquare) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          return Center(
            child: BarcodeWidget(
              barcode: barcode.type.barcode,
              data: value,
              width: side,
              height: side,
              drawText: false,
            ),
          );
        },
      );
    }
    return BarcodeWidget(
      barcode: barcode.type.barcode,
      data: value,
      drawText: barcode.drawsTextUnderBars,
      textPadding: barcodeTextGapMm * pixelsPerMm,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: _pointsToPixels(barcode.textSizePt),
        color: Colors.black,
      ),
    );
  }
}

class _WrongBarcodeValue extends StatelessWidget {
  const _WrongBarcodeValue({required this.problem});

  final String problem;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: problem,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.06),
          border: Border.all(color: Colors.red),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(2),
        child: const FittedBox(
          child: Text(
            'Wrong value for this barcode',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.shape, this.lineWidthPx);

  final ShapeItem shape;
  final double lineWidthPx;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = lineWidthPx
      ..style = shape.filled && shape.shape != ShapeKind.line
          ? PaintingStyle.fill
          : PaintingStyle.stroke;
    final inset = paint.style == PaintingStyle.stroke ? lineWidthPx / 2 : 0.0;
    final area = Rect.fromLTWH(
      inset,
      inset,
      size.width - 2 * inset,
      size.height - 2 * inset,
    );
    switch (shape.shape) {
      case ShapeKind.line when size.width >= size.height:
        final y = size.height / 2;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      case ShapeKind.line:
        final x = size.width / 2;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      case ShapeKind.rectangle:
        canvas.drawRect(area, paint);
      case ShapeKind.ellipse:
        canvas.drawOval(area, paint);
    }
  }

  @override
  bool shouldRepaint(_ShapePainter oldDelegate) {
    return oldDelegate.shape != shape || oldDelegate.lineWidthPx != lineWidthPx;
  }
}
