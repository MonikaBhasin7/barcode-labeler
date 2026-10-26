import 'dart:math' as math;
import 'dart:typed_data';

import '../../../core/ids.dart';
import '../../../core/units.dart';
import '../../design/data/models/barcode_type.dart';
import '../../design/data/models/label_design.dart';
import '../../design/data/models/label_item.dart';
import '../../design/data/models/label_value.dart';

TextItem newTextItem(LabelDesign design) {
  return TextItem(
    id: newRandomId(),
    name: _nextName(design, 'Text'),
    frame: _centredFrame(design.sheet, 40, 8),
    value: const LabelValue(fixedText: 'Text'),
  );
}

BarcodeItem newBarcodeItem(LabelDesign design) {
  return BarcodeItem(
    id: newRandomId(),
    name: _nextName(design, 'Barcode'),
    frame: _centredFrame(design.sheet, 50, 18),
    value: LabelValue(fixedText: BarcodeType.code128.sampleData),
  );
}

BarcodeItem newQrCodeItem(LabelDesign design) {
  return BarcodeItem(
    id: newRandomId(),
    name: _nextName(design, 'QR code'),
    frame: _centredFrame(design.sheet, 20, 20),
    type: BarcodeType.qrCode,
    value: LabelValue(fixedText: BarcodeType.qrCode.sampleData),
  );
}

ShapeItem newShapeItem(LabelDesign design, ShapeKind shape) {
  final (width, height) = switch (shape) {
    ShapeKind.line => (40.0, 2.0),
    ShapeKind.rectangle => (30.0, 15.0),
    ShapeKind.ellipse => (15.0, 15.0),
  };
  return ShapeItem(
    id: newRandomId(),
    name: _nextName(design, shape.label),
    frame: _centredFrame(design.sheet, width, height),
    shape: shape,
  );
}

PictureItem newPictureItem(
  LabelDesign design,
  Uint8List imageBytes,
  double widthOverHeight,
) {
  const longestSideMm = 30.0;
  final width = widthOverHeight >= 1
      ? longestSideMm
      : longestSideMm * widthOverHeight;
  final height = widthOverHeight >= 1
      ? longestSideMm / widthOverHeight
      : longestSideMm;
  return PictureItem(
    id: newRandomId(),
    name: _nextName(design, 'Picture'),
    frame: _centredFrame(design.sheet, width, height),
    imageBytes: imageBytes,
  );
}

LabelItem duplicateOf(LabelItem item, LabelDesign design) {
  return item.copyWithCommon(
    id: newRandomId(),
    name: _nextName(design, '${item.name} copy'),
    frame: item.frame.movedBy(2, 2),
  );
}

ItemFrame _centredFrame(SheetLayout sheet, double widthMm, double heightMm) {
  final width = roundToTenthMm(math.min(widthMm, sheet.labelWidthMm * 0.8));
  final height = roundToTenthMm(math.min(heightMm, sheet.labelHeightMm * 0.8));
  return ItemFrame(
    x: roundToTenthMm((sheet.labelWidthMm - width) / 2),
    y: roundToTenthMm((sheet.labelHeightMm - height) / 2),
    width: width,
    height: height,
  );
}

String _nextName(LabelDesign design, String base) {
  final usedNames = {for (final item in design.items) item.name};
  var number = 1;
  while (usedNames.contains('$base $number')) {
    number++;
  }
  return '$base $number';
}
