import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';

const String _lettersUnderBars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

class BarcodeNumberSpacing {
  const BarcodeNumberSpacing({
    required this.descentEm,
    required this.letterTopEm,
  });

  factory BarcodeNumberSpacing.ofFont(Uint8List fontBytes) {
    final font = PdfTtfFont(PdfDocument(), ByteData.sublistView(fontBytes));
    return BarcodeNumberSpacing(
      descentEm: -font.descent,
      letterTopEm: font.stringMetrics(_lettersUnderBars).bottom,
    );
  }

  final double descentEm;
  final double letterTopEm;

  double get extraGapEm => math.max(0, descentEm + letterTopEm - 1);

  double get baselineEm => 1 - descentEm;
}
