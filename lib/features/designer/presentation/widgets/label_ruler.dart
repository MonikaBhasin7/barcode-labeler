import 'package:flutter/material.dart';

import '../../../../core/units.dart';

const double rulerThickness = 22;
const double _minTickGapPx = 4;

class LabelRuler extends StatelessWidget {
  const LabelRuler({
    super.key,
    required this.lengthMm,
    required this.pixelsPerMm,
    required this.axis,
    required this.unit,
  });

  final double lengthMm;
  final double pixelsPerMm;
  final Axis axis;
  final LengthUnit unit;

  @override
  Widget build(BuildContext context) {
    final length = lengthMm * pixelsPerMm;
    return CustomPaint(
      size: axis == Axis.horizontal
          ? Size(length, rulerThickness)
          : Size(rulerThickness, length),
      painter: _RulerPainter(
        lengthMm: lengthMm,
        pixelsPerMm: pixelsPerMm,
        axis: axis,
        scale: _RulerScale.forUnit(unit),
        tickColor: Theme.of(context).colorScheme.onSurfaceVariant,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class _RulerScale {
  const _RulerScale({
    required this.smallTickMm,
    required this.smallTicksPerMedium,
    required this.smallTicksPerNumber,
    required this.smallTicksPerShownUnit,
  });

  factory _RulerScale.forUnit(LengthUnit unit) {
    return switch (unit) {
      LengthUnit.mm => const _RulerScale(
        smallTickMm: 1,
        smallTicksPerMedium: 5,
        smallTicksPerNumber: 10,
        smallTicksPerShownUnit: 1,
      ),
      LengthUnit.cm => const _RulerScale(
        smallTickMm: 1,
        smallTicksPerMedium: 5,
        smallTicksPerNumber: 10,
        smallTicksPerShownUnit: 10,
      ),
      LengthUnit.inch => const _RulerScale(
        smallTickMm: 25.4 / 8,
        smallTicksPerMedium: 4,
        smallTicksPerNumber: 8,
        smallTicksPerShownUnit: 8,
      ),
    };
  }

  final double smallTickMm;
  final int smallTicksPerMedium;
  final int smallTicksPerNumber;
  final int smallTicksPerShownUnit;
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.lengthMm,
    required this.pixelsPerMm,
    required this.axis,
    required this.scale,
    required this.tickColor,
    required this.backgroundColor,
  });

  final double lengthMm;
  final double pixelsPerMm;
  final Axis axis;
  final _RulerScale scale;
  final Color tickColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1;
    final step = _ticksPerDrawnTick();
    final tickCount = (lengthMm / scale.smallTickMm).floor();
    for (var tick = 0; tick <= tickCount; tick += step) {
      final at = tick * scale.smallTickMm * pixelsPerMm;
      _drawTick(canvas, at, _tickLength(tick), tickPaint);
      if (tick % scale.smallTicksPerNumber == 0 && _hasRoomForNumbers) {
        _drawNumber(canvas, tick ~/ scale.smallTicksPerShownUnit, at);
      }
    }
  }

  int _ticksPerDrawnTick() {
    final smallGapPx = scale.smallTickMm * pixelsPerMm;
    if (smallGapPx >= _minTickGapPx) return 1;
    if (smallGapPx * scale.smallTicksPerMedium >= _minTickGapPx) {
      return scale.smallTicksPerMedium;
    }
    return scale.smallTicksPerNumber;
  }

  double _tickLength(int tick) {
    if (tick % scale.smallTicksPerNumber == 0) return rulerThickness * 0.6;
    if (tick % scale.smallTicksPerMedium == 0) return rulerThickness * 0.4;
    return rulerThickness * 0.25;
  }

  bool get _hasRoomForNumbers {
    return scale.smallTickMm * scale.smallTicksPerNumber * pixelsPerMm >= 24;
  }

  void _drawTick(Canvas canvas, double at, double tickLength, Paint paint) {
    if (axis == Axis.horizontal) {
      canvas.drawLine(
        Offset(at, rulerThickness),
        Offset(at, rulerThickness - tickLength),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(rulerThickness, at),
        Offset(rulerThickness - tickLength, at),
        paint,
      );
    }
  }

  void _drawNumber(Canvas canvas, int number, double at) {
    final painter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(fontFamily: 'Roboto', fontSize: 9, color: tickColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final position = axis == Axis.horizontal
        ? Offset(at + 2, 1)
        : Offset(2, at + 1);
    painter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) {
    return oldDelegate.lengthMm != lengthMm ||
        oldDelegate.pixelsPerMm != pixelsPerMm ||
        oldDelegate.scale.smallTicksPerShownUnit !=
            scale.smallTicksPerShownUnit ||
        oldDelegate.scale.smallTickMm != scale.smallTickMm ||
        oldDelegate.tickColor != tickColor;
  }
}
