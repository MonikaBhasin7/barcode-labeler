import 'package:barcode_labeler/features/design/data/models/label_font.dart';
import 'package:barcode_labeler/features/printing/application/barcode_number_spacing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_designs.dart';

void main() {
  test('a font that sits high gets extra room under the bars', () {
    const spacing = BarcodeNumberSpacing(descentEm: 0.29, letterTopEm: 0.76);

    expect(spacing.extraGapEm, closeTo(0.05, 0.0001));
  });

  test('the fonts the app ships with keep their gap as it was', () {
    final fonts = readBundledFonts();

    for (final font in LabelFont.values) {
      final spacing = BarcodeNumberSpacing.ofFont(
        fonts.filesFor(BuiltInFont(font)).regular,
      );

      expect(spacing.extraGapEm, 0, reason: font.label);
    }
  });

  test('the number sits on the same line it always did', () {
    final roboto = BarcodeNumberSpacing.ofFont(
      readBundledFonts().robotoFiles.regular,
    );

    expect(roboto.baselineEm, closeTo(0.756, 0.001));
  });
}
