import '../../../core/units.dart';
import '../data/models/label_design.dart';

class LabelSlot {
  const LabelSlot({required this.leftMm, required this.topMm});

  final double leftMm;
  final double topMm;
}

List<LabelSlot> labelSlotsInFillOrder(SheetLayout sheet) {
  return [
    if (sheet.fillOrder == FillOrder.acrossThenDown)
      for (var row = 0; row < sheet.rows; row++)
        for (var column = 0; column < sheet.columns; column++)
          _slotAt(sheet, row, column)
    else
      for (var column = 0; column < sheet.columns; column++)
        for (var row = 0; row < sheet.rows; row++) _slotAt(sheet, row, column),
  ];
}

LabelSlot _slotAt(SheetLayout sheet, int row, int column) {
  return LabelSlot(
    leftMm:
        sheet.marginLeftMm + column * (sheet.labelWidthMm + sheet.gapAcrossMm),
    topMm: sheet.marginTopMm + row * (sheet.labelHeightMm + sheet.gapDownMm),
  );
}

SheetLayout withMostLabelsThatFit(SheetLayout sheet) {
  return sheet.copyWith(
    columns: _labelsThatFit(
      sheet.pageWidthMm - 2 * sheet.marginLeftMm,
      sheet.labelWidthMm,
      sheet.gapAcrossMm,
    ),
    rows: _labelsThatFit(
      sheet.pageHeightMm - 2 * sheet.marginTopMm,
      sheet.labelHeightMm,
      sheet.gapDownMm,
    ),
  );
}

int _labelsThatFit(double spaceMm, double labelMm, double gapMm) {
  if (labelMm <= 0) return 1;
  final count = ((spaceMm + gapMm + 0.01) / (labelMm + gapMm)).floor();
  return count < 1 ? 1 : count;
}

SheetLayout withLabelFillingWholePage(SheetLayout sheet) {
  return sheet.copyWith(
    marginTopMm: 0,
    marginLeftMm: 0,
    gapAcrossMm: 0,
    gapDownMm: 0,
    labelWidthMm: sheet.pageWidthMm,
    labelHeightMm: sheet.pageHeightMm,
    columns: 1,
    rows: 1,
  );
}

String? sheetLayoutProblem(
  SheetLayout sheet, {
  LengthUnit unit = LengthUnit.mm,
}) {
  if (sheet.pageWidthMm <= 0 || sheet.pageHeightMm <= 0) {
    return 'Page width and height must be more than 0.';
  }
  if (sheet.labelWidthMm <= 0 || sheet.labelHeightMm <= 0) {
    return 'Label width and height must be more than 0.';
  }
  if (sheet.columns < 1 || sheet.rows < 1) {
    return 'There must be at least 1 label across and 1 label down.';
  }
  final usedWidthMm =
      sheet.marginLeftMm +
      sheet.columns * sheet.labelWidthMm +
      (sheet.columns - 1) * sheet.gapAcrossMm;
  if (usedWidthMm > sheet.pageWidthMm + 0.05) {
    return 'The labels go '
        '${unit.formatWithLabel(usedWidthMm - sheet.pageWidthMm)} '
        'past the right edge of the page.';
  }
  final usedHeightMm =
      sheet.marginTopMm +
      sheet.rows * sheet.labelHeightMm +
      (sheet.rows - 1) * sheet.gapDownMm;
  if (usedHeightMm > sheet.pageHeightMm + 0.05) {
    return 'The labels go '
        '${unit.formatWithLabel(usedHeightMm - sheet.pageHeightMm)} '
        'past the bottom edge of the page.';
  }
  return null;
}
