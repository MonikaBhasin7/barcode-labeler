import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';

import '../../../core/units.dart';
import '../../design/data/models/label_font.dart';
import '../../design/data/models/label_item.dart';
import 'label_print_request.dart';

const double _fitTolerancePt = 0.5;

class LabelTextChecker {
  LabelTextChecker(this._fonts);

  final LabelFonts _fonts;
  final PdfDocument _document = PdfDocument();
  final Map<(LabelFont, bool), PdfFont> _pdfFonts = {};

  String? problemWith(TextItem item, String text) {
    final font = _pdfFontFor(item);
    final unprintable = _firstUnprintableLetter(text, font);
    if (unprintable != null) {
      return 'has a letter that cannot be printed yet ("$unprintable"). '
          'Only English letters, numbers and common signs print.';
    }
    if (!_fitsInBox(item, text, font)) {
      return 'is too long for its box. Make the box bigger or the text smaller.';
    }
    return null;
  }

  PdfFont _pdfFontFor(TextItem item) {
    return _pdfFonts.putIfAbsent((item.font, item.bold), () {
      final files = _fonts.filesFor(item.font);
      final bytes = item.bold ? files.bold : files.regular;
      return PdfTtfFont(_document, ByteData.sublistView(bytes));
    });
  }

  String? _firstUnprintableLetter(String text, PdfFont font) {
    for (final rune in text.runes) {
      if (rune <= 32 || rune == 160) continue;
      if (!font.isRuneSupported(rune)) return String.fromCharCode(rune);
    }
    return null;
  }

  bool _fitsInBox(TextItem item, String text, PdfFont font) {
    final turned = item.rotation.swapsWidthAndHeight;
    final frame = item.frame;
    final boxWidthPt = (turned ? frame.height : frame.width) * pointsPerMm;
    final boxHeightPt = (turned ? frame.width : frame.height) * pointsPerMm;
    final lineHeightPt = (font.ascent - font.descent) * item.fontSizePt;
    final lines = _lineCount(text, font, item.fontSizePt, boxWidthPt);
    return lines * lineHeightPt <= boxHeightPt + _fitTolerancePt;
  }

  int _lineCount(String text, PdfFont font, double fontSize, double widthPt) {
    var lines = 0;
    for (final paragraph in text.split('\n')) {
      lines += _wrappedLineCount(paragraph, font, fontSize, widthPt);
    }
    return lines;
  }

  int _wrappedLineCount(
    String paragraph,
    PdfFont font,
    double fontSize,
    double widthPt,
  ) {
    if (paragraph.isEmpty) return 1;
    final spaceWidth = _widthOf(' ', font, fontSize);
    var lines = 1;
    var lineWidth = 0.0;
    for (final word in paragraph.split(' ')) {
      final wordWidth = _widthOf(word, font, fontSize);
      if (wordWidth > widthPt + _fitTolerancePt) {
        lines += (wordWidth / math.max(widthPt, 1)).ceil();
        lineWidth = 0;
        continue;
      }
      final widthWithWord = lineWidth == 0
          ? wordWidth
          : lineWidth + spaceWidth + wordWidth;
      if (widthWithWord <= widthPt + _fitTolerancePt) {
        lineWidth = widthWithWord;
      } else {
        lines++;
        lineWidth = wordWidth;
      }
    }
    return lines;
  }

  double _widthOf(String text, PdfFont font, double fontSize) {
    if (text.isEmpty) return 0;
    return font.stringMetrics(text).advanceWidth * fontSize;
  }
}
