import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../design/application/sheet_geometry.dart';
import '../../../design/data/models/label_design.dart';

class SheetPreview extends StatelessWidget {
  const SheetPreview({super.key, required this.sheet, this.maxHeight = 360});

  final SheetLayout sheet;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          constraints.maxWidth / sheet.pageWidthMm,
          maxHeight / sheet.pageHeightMm,
        );
        return SizedBox(
          width: sheet.pageWidthMm * scale,
          height: sheet.pageHeightMm * scale,
          child: CustomPaint(
            painter: _SheetPainter(
              sheet: sheet,
              pixelsPerMm: scale,
              labelColor: Theme.of(context).colorScheme.primaryContainer,
              outlineColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      },
    );
  }
}

class _SheetPainter extends CustomPainter {
  _SheetPainter({
    required this.sheet,
    required this.pixelsPerMm,
    required this.labelColor,
    required this.outlineColor,
  });

  final SheetLayout sheet;
  final double pixelsPerMm;
  final Color labelColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = Colors.black45
        ..style = PaintingStyle.stroke,
    );
    final fill = Paint()..color = labelColor;
    final outline = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke;
    final slots = labelSlotsInFillOrder(sheet);
    final showNumbers = slots.length <= 120;
    for (final (index, slot) in slots.indexed) {
      final rect = Rect.fromLTWH(
        slot.leftMm * pixelsPerMm,
        slot.topMm * pixelsPerMm,
        sheet.labelWidthMm * pixelsPerMm,
        sheet.labelHeightMm * pixelsPerMm,
      );
      canvas
        ..drawRect(rect, fill)
        ..drawRect(rect, outline);
      if (showNumbers) _drawNumber(canvas, rect, index + 1);
    }
  }

  void _drawNumber(Canvas canvas, Rect rect, int number) {
    final painter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: math.min(12, rect.height * 0.5),
          color: outlineColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (painter.width > rect.width) return;
    painter.paint(
      canvas,
      rect.center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_SheetPainter oldDelegate) {
    return oldDelegate.sheet != sheet || oldDelegate.pixelsPerMm != pixelsPerMm;
  }
}
