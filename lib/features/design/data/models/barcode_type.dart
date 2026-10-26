import 'package:barcode/barcode.dart';

enum BarcodeType {
  code128('Code 128', '12345678'),
  code39('Code 39', 'ABC123'),
  code93('Code 93', 'ABC123'),
  ean13('EAN-13', '890123456789'),
  ean8('EAN-8', '1234567'),
  upcA('UPC-A', '01234567890'),
  upcE('UPC-E', '123456'),
  itf('Interleaved 2 of 5', '12345678'),
  itf14('ITF-14', '1234567890123'),
  codabar('Codabar', '123456'),
  qrCode('QR code', 'ABC123', isTwoDimensional: true, isSquare: true),
  dataMatrix('Data Matrix', 'ABC123', isTwoDimensional: true, isSquare: true),
  pdf417('PDF417', 'ABC123', isTwoDimensional: true);

  const BarcodeType(
    this.label,
    this.sampleData, {
    this.isTwoDimensional = false,
    this.isSquare = false,
  });

  final String label;
  final String sampleData;
  final bool isTwoDimensional;
  final bool isSquare;

  Barcode get barcode => switch (this) {
    BarcodeType.code128 => Barcode.code128(),
    BarcodeType.code39 => Barcode.code39(),
    BarcodeType.code93 => Barcode.code93(),
    BarcodeType.ean13 => Barcode.ean13(),
    BarcodeType.ean8 => Barcode.ean8(),
    BarcodeType.upcA => Barcode.upcA(),
    BarcodeType.upcE => Barcode.upcE(),
    BarcodeType.itf => Barcode.itf(),
    BarcodeType.itf14 => Barcode.itf14(),
    BarcodeType.codabar => Barcode.codabar(),
    BarcodeType.qrCode => Barcode.qrCode(),
    BarcodeType.dataMatrix => Barcode.dataMatrix(),
    BarcodeType.pdf417 => Barcode.pdf417(),
  };

  String? problemWithValue(String value) {
    if (value.isEmpty) return 'The value is empty.';
    try {
      if (isTwoDimensional) {
        barcode.verify(value);
      } else {
        barcode.make(value, width: 200, height: 80, drawText: false).toList();
      }
      return null;
    } on BarcodeException catch (error) {
      return error.message;
    }
  }
}
