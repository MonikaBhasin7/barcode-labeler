import 'package:barcode_labeler/features/design/application/sheet_geometry.dart';
import 'package:barcode_labeler/features/design/data/models/label_design.dart';
import 'package:flutter_test/flutter_test.dart';

const SheetLayout threeByTwoSheet = SheetLayout(
  paper: PaperSize.a4,
  pageWidthMm: 210,
  pageHeightMm: 297,
  marginTopMm: 10,
  marginLeftMm: 5,
  labelWidthMm: 60,
  labelHeightMm: 30,
  gapAcrossMm: 2,
  gapDownMm: 4,
  columns: 3,
  rows: 2,
);

void main() {
  test('places labels left to right, then down', () {
    final slots = labelSlotsInFillOrder(threeByTwoSheet);

    expect(slots.length, 6);
    expect((slots[1].leftMm, slots[1].topMm), (67.0, 10.0));
    expect((slots[3].leftMm, slots[3].topMm), (5.0, 44.0));
  });

  test('places labels top to bottom, then across', () {
    final slots = labelSlotsInFillOrder(
      threeByTwoSheet.copyWith(fillOrder: FillOrder.downThenAcross),
    );

    expect((slots[1].leftMm, slots[1].topMm), (5.0, 44.0));
    expect((slots[2].leftMm, slots[2].topMm), (67.0, 10.0));
  });

  test('fits as many labels as the page allows', () {
    final fitted = withMostLabelsThatFit(threeByTwoSheet);

    expect(fitted.columns, 3);
    expect(fitted.rows, 8);
    expect(sheetLayoutProblem(fitted), isNull);
  });

  test('reports labels that go past the page edge', () {
    final tooWide = threeByTwoSheet.copyWith(columns: 4);

    expect(sheetLayoutProblem(tooWide), contains('right edge'));
  });

  test('one label can fill the whole page', () {
    final whole = withLabelFillingWholePage(threeByTwoSheet);

    expect((whole.labelWidthMm, whole.labelHeightMm), (210.0, 297.0));
    expect(whole.labelsPerSheet, 1);
  });
}
