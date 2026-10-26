import '../../../../core/json_reading.dart';

enum ValueSourceKind {
  fixedText('Fixed text'),
  excelColumn('Excel column'),
  serialNumber('Serial number'),
  date('Date'),
  typedWhenPrinting('Typed when printing'),
  joinedParts('Join several parts'),
  sameAsItem('Same as another item');

  const ValueSourceKind(this.label);

  final String label;
}

const List<ValueSourceKind> partValueKinds = [
  ValueSourceKind.fixedText,
  ValueSourceKind.excelColumn,
  ValueSourceKind.serialNumber,
  ValueSourceKind.date,
  ValueSourceKind.typedWhenPrinting,
];

const List<String> datePatternChoices = [
  'dd/MM/yyyy',
  'dd-MM-yyyy',
  'dd.MM.yyyy',
  'dd-MMM-yyyy',
  'dd MMM yyyy',
  'MM/yyyy',
  'MMM yyyy',
  'yyyy',
  'yyyy-MM-dd',
  'ddMMyy',
  'HH:mm',
  'dd/MM/yyyy HH:mm',
];

class SerialNumberRule {
  const SerialNumberRule({
    this.start = 1,
    this.step = 1,
    this.repeatEvery = 1,
    this.minDigits = 0,
    this.countDown = false,
  });

  factory SerialNumberRule.fromJson(Map<String, dynamic> json) {
    return SerialNumberRule(
      start: readInt(json, 'start', 1),
      step: readInt(json, 'step', 1),
      repeatEvery: readInt(json, 'repeatEvery', 1),
      minDigits: readInt(json, 'minDigits', 0),
      countDown: readBool(json, 'countDown', false),
    );
  }

  final int start;
  final int step;
  final int repeatEvery;
  final int minDigits;
  final bool countDown;

  SerialNumberRule copyWith({
    int? start,
    int? step,
    int? repeatEvery,
    int? minDigits,
    bool? countDown,
  }) {
    return SerialNumberRule(
      start: start ?? this.start,
      step: step ?? this.step,
      repeatEvery: repeatEvery ?? this.repeatEvery,
      minDigits: minDigits ?? this.minDigits,
      countDown: countDown ?? this.countDown,
    );
  }

  Map<String, dynamic> toJson() => {
    'start': start,
    'step': step,
    'repeatEvery': repeatEvery,
    'minDigits': minDigits,
    'countDown': countDown,
  };
}

class DateRule {
  const DateRule({this.pattern = 'dd/MM/yyyy', this.addDays = 0});

  factory DateRule.fromJson(Map<String, dynamic> json) {
    return DateRule(
      pattern: readString(json, 'pattern', 'dd/MM/yyyy'),
      addDays: readInt(json, 'addDays', 0),
    );
  }

  final String pattern;
  final int addDays;

  DateRule copyWith({String? pattern, int? addDays}) {
    return DateRule(
      pattern: pattern ?? this.pattern,
      addDays: addDays ?? this.addDays,
    );
  }

  Map<String, dynamic> toJson() => {'pattern': pattern, 'addDays': addDays};
}

class LabelValue {
  const LabelValue({
    this.kind = ValueSourceKind.fixedText,
    this.fixedText = '',
    this.excelColumn = '',
    this.serial = const SerialNumberRule(),
    this.date = const DateRule(),
    this.sameAsItemId = '',
    this.question = '',
    this.parts = const [],
    this.prefix = '',
    this.suffix = '',
  });

  factory LabelValue.fromJson(Map<String, dynamic> json) {
    final parts = json['parts'];
    return LabelValue(
      kind: readEnum(
        ValueSourceKind.values,
        json['kind'],
        ValueSourceKind.fixedText,
      ),
      fixedText: readString(json, 'fixedText', ''),
      excelColumn: readString(json, 'excelColumn', ''),
      serial: SerialNumberRule.fromJson(readMap(json, 'serial')),
      date: DateRule.fromJson(readMap(json, 'date')),
      sameAsItemId: readString(json, 'sameAsItemId', ''),
      question: readString(json, 'question', ''),
      parts: [
        if (parts is List)
          for (final part in parts.whereType<Map<String, dynamic>>())
            ValuePart.fromJson(part),
      ],
      prefix: readString(json, 'prefix', ''),
      suffix: readString(json, 'suffix', ''),
    );
  }

  final ValueSourceKind kind;
  final String fixedText;
  final String excelColumn;
  final SerialNumberRule serial;
  final DateRule date;
  final String sameAsItemId;
  final String question;
  final List<ValuePart> parts;
  final String prefix;
  final String suffix;

  LabelValue copyWith({
    ValueSourceKind? kind,
    String? fixedText,
    String? excelColumn,
    SerialNumberRule? serial,
    DateRule? date,
    String? sameAsItemId,
    String? question,
    List<ValuePart>? parts,
    String? prefix,
    String? suffix,
  }) {
    return LabelValue(
      kind: kind ?? this.kind,
      fixedText: fixedText ?? this.fixedText,
      excelColumn: excelColumn ?? this.excelColumn,
      serial: serial ?? this.serial,
      date: date ?? this.date,
      sameAsItemId: sameAsItemId ?? this.sameAsItemId,
      question: question ?? this.question,
      parts: parts ?? this.parts,
      prefix: prefix ?? this.prefix,
      suffix: suffix ?? this.suffix,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'fixedText': fixedText,
    'excelColumn': excelColumn,
    'serial': serial.toJson(),
    'date': date.toJson(),
    'sameAsItemId': sameAsItemId,
    'question': question,
    'parts': [for (final part in parts) part.toJson()],
    'prefix': prefix,
    'suffix': suffix,
  };
}

class ValuePart {
  const ValuePart({required this.id, required this.value});

  factory ValuePart.fromJson(Map<String, dynamic> json) {
    return ValuePart(
      id: readString(json, 'id', ''),
      value: LabelValue.fromJson(readMap(json, 'value')),
    );
  }

  final String id;
  final LabelValue value;

  ValuePart copyWith({LabelValue? value}) {
    return ValuePart(id: id, value: value ?? this.value);
  }

  Map<String, dynamic> toJson() => {'id': id, 'value': value.toJson()};
}
