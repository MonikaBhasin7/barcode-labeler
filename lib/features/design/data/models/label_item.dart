import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/json_reading.dart';
import 'barcode_type.dart';
import 'label_font.dart';
import 'label_value.dart';

enum QuarterTurn {
  none(0, '0°'),
  quarter(1, '90°'),
  half(2, '180°'),
  threeQuarters(3, '270°');

  const QuarterTurn(this.turns, this.label);

  final int turns;
  final String label;

  bool get swapsWidthAndHeight => turns.isOdd;
}

enum TextAlignment {
  left('Left'),
  center('Centre'),
  right('Right');

  const TextAlignment(this.label);

  final String label;
}

enum ShapeKind {
  rectangle('Box'),
  ellipse('Circle'),
  line('Line');

  const ShapeKind(this.label);

  final String label;
}

class ItemFrame {
  const ItemFrame({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory ItemFrame.fromJson(Map<String, dynamic> json) {
    return ItemFrame(
      x: readDouble(json, 'x', 0),
      y: readDouble(json, 'y', 0),
      width: readDouble(json, 'width', 10),
      height: readDouble(json, 'height', 10),
    );
  }

  final double x;
  final double y;
  final double width;
  final double height;

  ItemFrame copyWith({double? x, double? y, double? width, double? height}) {
    return ItemFrame(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  ItemFrame movedBy(double dxMm, double dyMm) {
    return copyWith(x: x + dxMm, y: y + dyMm);
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

sealed class LabelItem {
  const LabelItem({
    required this.id,
    required this.name,
    required this.frame,
    required this.rotation,
  });

  static LabelItem fromJson(Map<String, dynamic> json) {
    return switch (json['kind']) {
      'text' => TextItem.fromJson(json),
      'barcode' => BarcodeItem.fromJson(json),
      'shape' => ShapeItem.fromJson(json),
      'picture' => PictureItem.fromJson(json),
      _ => throw FormatException('Unknown label item kind: ${json['kind']}'),
    };
  }

  final String id;
  final String name;
  final ItemFrame frame;
  final QuarterTurn rotation;

  String get kindLabel;

  LabelValue? get labelValue => null;

  LabelItem copyWithCommon({
    String? id,
    String? name,
    ItemFrame? frame,
    QuarterTurn? rotation,
  });

  Map<String, dynamic> toJson();

  Map<String, dynamic> commonJson(String kind) => {
    'kind': kind,
    'id': id,
    'name': name,
    'frame': frame.toJson(),
    'rotation': rotation.name,
  };
}

String _readId(Map<String, dynamic> json) => readString(json, 'id', '');

String _readName(Map<String, dynamic> json) => readString(json, 'name', '');

ItemFrame _readFrame(Map<String, dynamic> json) {
  return ItemFrame.fromJson(readMap(json, 'frame'));
}

QuarterTurn _readRotation(Map<String, dynamic> json) {
  return readEnum(QuarterTurn.values, json['rotation'], QuarterTurn.none);
}

class TextItem extends LabelItem {
  const TextItem({
    required super.id,
    required super.name,
    required super.frame,
    super.rotation = QuarterTurn.none,
    required this.value,
    this.font = robotoFont,
    this.fontSizePt = 12,
    this.bold = false,
    this.alignment = TextAlignment.left,
  });

  factory TextItem.fromJson(Map<String, dynamic> json) {
    return TextItem(
      id: _readId(json),
      name: _readName(json),
      frame: _readFrame(json),
      rotation: _readRotation(json),
      value: LabelValue.fromJson(readMap(json, 'value')),
      font: TextFont.fromJson(json),
      fontSizePt: readDouble(json, 'fontSizePt', 12),
      bold: readBool(json, 'bold', false),
      alignment: readEnum(
        TextAlignment.values,
        json['alignment'],
        TextAlignment.left,
      ),
    );
  }

  final LabelValue value;
  final TextFont font;
  final double fontSizePt;
  final bool bold;
  final TextAlignment alignment;

  @override
  String get kindLabel => 'Text';

  @override
  LabelValue get labelValue => value;

  TextItem copyWith({
    LabelValue? value,
    TextFont? font,
    double? fontSizePt,
    bool? bold,
    TextAlignment? alignment,
  }) {
    return TextItem(
      id: id,
      name: name,
      frame: frame,
      rotation: rotation,
      value: value ?? this.value,
      font: font ?? this.font,
      fontSizePt: fontSizePt ?? this.fontSizePt,
      bold: bold ?? this.bold,
      alignment: alignment ?? this.alignment,
    );
  }

  @override
  TextItem copyWithCommon({
    String? id,
    String? name,
    ItemFrame? frame,
    QuarterTurn? rotation,
  }) {
    return TextItem(
      id: id ?? this.id,
      name: name ?? this.name,
      frame: frame ?? this.frame,
      rotation: rotation ?? this.rotation,
      value: value,
      font: font,
      fontSizePt: fontSizePt,
      bold: bold,
      alignment: alignment,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...commonJson('text'),
    'value': value.toJson(),
    ...font.toJson(),
    'fontSizePt': fontSizePt,
    'bold': bold,
    'alignment': alignment.name,
  };
}

class BarcodeItem extends LabelItem {
  const BarcodeItem({
    required super.id,
    required super.name,
    required super.frame,
    super.rotation = QuarterTurn.none,
    required this.value,
    this.type = BarcodeType.code128,
    this.showText = true,
    this.textSizePt = 9,
  });

  factory BarcodeItem.fromJson(Map<String, dynamic> json) {
    return BarcodeItem(
      id: _readId(json),
      name: _readName(json),
      frame: _readFrame(json),
      rotation: _readRotation(json),
      value: LabelValue.fromJson(readMap(json, 'value')),
      type: readEnum(BarcodeType.values, json['type'], BarcodeType.code128),
      showText: readBool(json, 'showText', true),
      textSizePt: readDouble(json, 'textSizePt', 9),
    );
  }

  final LabelValue value;
  final BarcodeType type;
  final bool showText;
  final double textSizePt;

  bool get drawsTextUnderBars => showText && !type.isTwoDimensional;

  @override
  String get kindLabel => 'Barcode';

  @override
  LabelValue get labelValue => value;

  BarcodeItem copyWith({
    LabelValue? value,
    BarcodeType? type,
    bool? showText,
    double? textSizePt,
  }) {
    return BarcodeItem(
      id: id,
      name: name,
      frame: frame,
      rotation: rotation,
      value: value ?? this.value,
      type: type ?? this.type,
      showText: showText ?? this.showText,
      textSizePt: textSizePt ?? this.textSizePt,
    );
  }

  @override
  BarcodeItem copyWithCommon({
    String? id,
    String? name,
    ItemFrame? frame,
    QuarterTurn? rotation,
  }) {
    return BarcodeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      frame: frame ?? this.frame,
      rotation: rotation ?? this.rotation,
      value: value,
      type: type,
      showText: showText,
      textSizePt: textSizePt,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...commonJson('barcode'),
    'value': value.toJson(),
    'type': type.name,
    'showText': showText,
    'textSizePt': textSizePt,
  };
}

class ShapeItem extends LabelItem {
  const ShapeItem({
    required super.id,
    required super.name,
    required super.frame,
    super.rotation = QuarterTurn.none,
    this.shape = ShapeKind.rectangle,
    this.lineWidthMm = 0.3,
    this.filled = false,
  });

  factory ShapeItem.fromJson(Map<String, dynamic> json) {
    return ShapeItem(
      id: _readId(json),
      name: _readName(json),
      frame: _readFrame(json),
      rotation: _readRotation(json),
      shape: readEnum(ShapeKind.values, json['shape'], ShapeKind.rectangle),
      lineWidthMm: readDouble(json, 'lineWidthMm', 0.3),
      filled: readBool(json, 'filled', false),
    );
  }

  final ShapeKind shape;
  final double lineWidthMm;
  final bool filled;

  @override
  String get kindLabel => shape.label;

  ShapeItem copyWith({ShapeKind? shape, double? lineWidthMm, bool? filled}) {
    return ShapeItem(
      id: id,
      name: name,
      frame: frame,
      rotation: rotation,
      shape: shape ?? this.shape,
      lineWidthMm: lineWidthMm ?? this.lineWidthMm,
      filled: filled ?? this.filled,
    );
  }

  @override
  ShapeItem copyWithCommon({
    String? id,
    String? name,
    ItemFrame? frame,
    QuarterTurn? rotation,
  }) {
    return ShapeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      frame: frame ?? this.frame,
      rotation: rotation ?? this.rotation,
      shape: shape,
      lineWidthMm: lineWidthMm,
      filled: filled,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...commonJson('shape'),
    'shape': shape.name,
    'lineWidthMm': lineWidthMm,
    'filled': filled,
  };
}

class PictureItem extends LabelItem {
  const PictureItem({
    required super.id,
    required super.name,
    required super.frame,
    super.rotation = QuarterTurn.none,
    required this.imageBytes,
  });

  factory PictureItem.fromJson(Map<String, dynamic> json) {
    return PictureItem(
      id: _readId(json),
      name: _readName(json),
      frame: _readFrame(json),
      rotation: _readRotation(json),
      imageBytes: base64Decode(readString(json, 'imageBase64', '')),
    );
  }

  final Uint8List imageBytes;

  @override
  String get kindLabel => 'Picture';

  PictureItem copyWith({Uint8List? imageBytes}) {
    return PictureItem(
      id: id,
      name: name,
      frame: frame,
      rotation: rotation,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }

  @override
  PictureItem copyWithCommon({
    String? id,
    String? name,
    ItemFrame? frame,
    QuarterTurn? rotation,
  }) {
    return PictureItem(
      id: id ?? this.id,
      name: name ?? this.name,
      frame: frame ?? this.frame,
      rotation: rotation ?? this.rotation,
      imageBytes: imageBytes,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...commonJson('picture'),
    'imageBase64': base64Encode(imageBytes),
  };
}
