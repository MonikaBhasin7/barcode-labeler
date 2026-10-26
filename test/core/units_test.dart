import 'package:barcode_labeler/core/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shows millimetres in each unit', () {
    expect(LengthUnit.mm.formatWithLabel(25.4), '25.4 mm');
    expect(LengthUnit.cm.formatWithLabel(25.4), '2.54 cm');
    expect(LengthUnit.inch.formatWithLabel(25.4), '1 in');
  });

  test('typed values turn back into millimetres', () {
    expect(LengthUnit.cm.toMm(2.5), 25);
    expect(LengthUnit.inch.toMm(0.5), 12.7);
  });

  test('drops zeros that add nothing', () {
    expect(LengthUnit.mm.format(10), '10');
    expect(LengthUnit.cm.format(15), '1.5');
  });
}
