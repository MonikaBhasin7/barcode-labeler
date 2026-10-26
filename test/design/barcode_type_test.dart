import 'package:barcode_labeler/features/design/data/models/barcode_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final type in BarcodeType.values) {
    test('${type.label} accepts its sample value', () {
      expect(type.problemWithValue(type.sampleData), isNull);
    });
  }

  test('EAN-13 refuses letters', () {
    expect(BarcodeType.ean13.problemWithValue('ABC'), isNotNull);
  });

  test('an empty value is a problem', () {
    expect(BarcodeType.code128.problemWithValue(''), 'The value is empty.');
  });
}
