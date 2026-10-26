import '../../../../core/json_reading.dart';

class PrinterOffset {
  const PrinterOffset({this.rightMm = 0, this.downMm = 0});

  factory PrinterOffset.fromJson(Map<String, dynamic> json) {
    return PrinterOffset(
      rightMm: readDouble(json, 'rightMm', 0),
      downMm: readDouble(json, 'downMm', 0),
    );
  }

  static const PrinterOffset none = PrinterOffset();

  final double rightMm;
  final double downMm;

  PrinterOffset copyWith({double? rightMm, double? downMm}) {
    return PrinterOffset(
      rightMm: rightMm ?? this.rightMm,
      downMm: downMm ?? this.downMm,
    );
  }

  Map<String, dynamic> toJson() => {'rightMm': rightMm, 'downMm': downMm};
}
