import 'package:intl/intl.dart';

String excelCellText(
  String rawValue,
  String formatCode, {
  required bool usesDate1904,
}) {
  if (rawValue.isEmpty) return '';
  final number = double.tryParse(rawValue);
  if (number == null) return rawValue;
  final tokens = _tokensOf(formatCode.split(';').first);
  final code = tokens.where((token) => token.isCode).map((t) => t.text).join();
  final lowerCode = code.toLowerCase();
  if (lowerCode.isEmpty || lowerCode == 'general' || lowerCode.contains('@')) {
    return _withLiterals(tokens, generalNumberText(rawValue, number));
  }
  if (_isDateCode(lowerCode)) {
    return _excelDateText(number, tokens, usesDate1904: usesDate1904);
  }
  return _withLiterals(tokens, _numberText(number, code, rawValue));
}

String generalNumberText(String rawValue, double number) {
  if (RegExp(r'^-?\d+$').hasMatch(rawValue)) return rawValue;
  if (number == number.roundToDouble() && number.abs() < 1e15) {
    return number.toInt().toString();
  }
  return double.parse(number.toStringAsFixed(10)).toString();
}

String decodeExcelEscapes(String text) {
  return text
      .replaceAllMapped(
        RegExp(r'_x([0-9A-Fa-f]{4})_'),
        (match) => String.fromCharCode(int.parse(match[1]!, radix: 16)),
      )
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
}

class _FormatToken {
  const _FormatToken.code(this.text) : isCode = true;

  const _FormatToken.literal(this.text) : isCode = false;

  final String text;
  final bool isCode;
}

List<_FormatToken> _tokensOf(String section) {
  final tokens = <_FormatToken>[];
  final code = StringBuffer();
  void finishCode() {
    if (code.isEmpty) return;
    tokens.add(_FormatToken.code(code.toString()));
    code.clear();
  }

  var index = 0;
  while (index < section.length) {
    final char = section[index];
    if (char == '"') {
      final end = section.indexOf('"', index + 1);
      final stop = end < 0 ? section.length : end;
      finishCode();
      tokens.add(_FormatToken.literal(section.substring(index + 1, stop)));
      index = stop + 1;
    } else if (char == r'\' && index + 1 < section.length) {
      finishCode();
      tokens.add(_FormatToken.literal(section[index + 1]));
      index += 2;
    } else if (char == '[') {
      final end = section.indexOf(']', index);
      index = end < 0 ? section.length : end + 1;
    } else if (char == '_' || char == '*') {
      index += 2;
    } else {
      code.write(char);
      index++;
    }
  }
  finishCode();
  return tokens;
}

String _withLiterals(List<_FormatToken> tokens, String numberText) {
  final firstCode = tokens.indexWhere((token) => token.isCode);
  final lastCode = tokens.lastIndexWhere((token) => token.isCode);
  if (firstCode < 0) return numberText;
  final before = tokens.take(firstCode).map((token) => token.text).join();
  final after = tokens.skip(lastCode + 1).map((token) => token.text).join();
  return '$before$numberText$after';
}

bool _isDateCode(String lowerCode) {
  return RegExp(r'[ydhs]').hasMatch(lowerCode) ||
      RegExp(r'^m+$').hasMatch(lowerCode) ||
      lowerCode.contains('am/pm');
}

String _numberText(double number, String code, String rawValue) {
  if (!RegExp(r'^[#0,.%]+$').hasMatch(code)) {
    return generalNumberText(rawValue, number);
  }
  try {
    return NumberFormat(code, 'en_US').format(number);
  } on Object {
    return generalNumberText(rawValue, number);
  }
}

String _excelDateText(
  double serial,
  List<_FormatToken> tokens, {
  required bool usesDate1904,
}) {
  final base = usesDate1904 ? DateTime.utc(1904) : DateTime.utc(1899, 12, 30);
  final moment = base.add(Duration(milliseconds: (serial * 86400000).round()));
  try {
    return DateFormat(_intlDatePattern(tokens), 'en_US').format(moment);
  } on Object {
    return DateFormat('dd/MM/yyyy').format(moment);
  }
}

String _intlDatePattern(List<_FormatToken> tokens) {
  final parts = <_DatePart>[];
  for (final token in tokens) {
    if (token.isCode) {
      parts.addAll(_datePartsOf(token.text));
    } else {
      parts.add(_DatePart.literal(token.text));
    }
  }
  final usesTwelveHours = parts.any((part) => part.letter == 'a');
  final pattern = StringBuffer();
  for (var index = 0; index < parts.length; index++) {
    pattern.write(_intlPieceFor(parts, index, usesTwelveHours));
  }
  return pattern.toString();
}

class _DatePart {
  const _DatePart.unit(this.letter, this.length) : literal = '';

  const _DatePart.literal(this.literal) : letter = '', length = 0;

  final String letter;
  final int length;
  final String literal;
}

List<_DatePart> _datePartsOf(String code) {
  final parts = <_DatePart>[];
  final lower = code.toLowerCase();
  var index = 0;
  while (index < lower.length) {
    if (lower.startsWith('am/pm', index)) {
      parts.add(const _DatePart.unit('a', 1));
      index += 5;
      continue;
    }
    if (lower.startsWith('a/p', index)) {
      parts.add(const _DatePart.unit('a', 1));
      index += 3;
      continue;
    }
    final letter = lower[index];
    if ('ymdhs'.contains(letter)) {
      var end = index;
      while (end < lower.length && lower[end] == letter) {
        end++;
      }
      parts.add(_DatePart.unit(letter, end - index));
      index = end;
    } else {
      parts.add(_DatePart.literal(code[index]));
      index++;
    }
  }
  return parts;
}

String _intlPieceFor(List<_DatePart> parts, int index, bool usesTwelveHours) {
  final part = parts[index];
  return switch (part.letter) {
    '' => _quotedLiteral(part.literal),
    'y' => part.length <= 2 ? 'yy' : 'yyyy',
    'd' => switch (part.length) {
      1 => 'd',
      2 => 'dd',
      3 => 'EEE',
      _ => 'EEEE',
    },
    'h' => (usesTwelveHours ? 'h' : 'H') * (part.length >= 2 ? 2 : 1),
    's' => part.length >= 2 ? 'ss' : 's',
    'a' => 'a',
    'm' when _isMinutes(parts, index) => part.length >= 2 ? 'mm' : 'm',
    _ => switch (part.length) {
      1 => 'M',
      2 => 'MM',
      3 => 'MMM',
      _ => 'MMMM',
    },
  };
}

bool _isMinutes(List<_DatePart> parts, int index) {
  for (var before = index - 1; before >= 0; before--) {
    final letter = parts[before].letter;
    if (letter.isEmpty) continue;
    if (letter == 'h') return true;
    break;
  }
  for (var after = index + 1; after < parts.length; after++) {
    final letter = parts[after].letter;
    if (letter.isEmpty) continue;
    return letter == 's';
  }
  return false;
}

String _quotedLiteral(String text) {
  if (text.isEmpty) return '';
  if (!RegExp('[A-Za-z\']').hasMatch(text)) return text;
  return "'${text.replaceAll("'", "''")}'";
}
