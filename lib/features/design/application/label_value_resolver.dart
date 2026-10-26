import 'package:intl/intl.dart';

import '../data/models/label_design.dart';
import '../data/models/label_item.dart';
import '../data/models/label_value.dart';

class LabelValueContext {
  const LabelValueContext({
    required this.row,
    required this.recordIndex,
    required this.serialStarts,
    required this.typedAnswers,
    required this.today,
  });

  final Map<String, String> row;
  final int recordIndex;
  final Map<String, int> serialStarts;
  final Map<String, String> typedAnswers;
  final DateTime today;
}

class LabelValueResolver {
  LabelValueResolver(List<LabelItem> items)
    : _itemsById = {for (final item in items) item.id: item};

  final Map<String, LabelItem> _itemsById;

  String resolve(LabelItem item, LabelValueContext context) {
    final value = item.labelValue;
    if (value == null) return '';
    return '${value.prefix}${_sourceText(item.id, value, context)}'
        '${value.suffix}';
  }

  String _sourceText(String key, LabelValue value, LabelValueContext context) {
    return switch (value.kind) {
      ValueSourceKind.fixedText => value.fixedText,
      ValueSourceKind.excelColumn => context.row[value.excelColumn] ?? '',
      ValueSourceKind.serialNumber => serialNumberText(
        value.serial,
        context.serialStarts[key] ?? value.serial.start,
        context.recordIndex,
      ),
      ValueSourceKind.date => dateText(value.date, context.today),
      ValueSourceKind.typedWhenPrinting => context.typedAnswers[key] ?? '',
      ValueSourceKind.joinedParts => _joinedPartsText(key, value, context),
      ValueSourceKind.sameAsItem => _linkedItemText(
        value.sameAsItemId,
        context,
      ),
    };
  }

  String _joinedPartsText(
    String itemId,
    LabelValue value,
    LabelValueContext context,
  ) {
    return [
      for (final part in value.parts)
        if (partValueKinds.contains(part.value.kind))
          _sourceText(partValueKey(itemId, part.id), part.value, context),
    ].join();
  }

  String _linkedItemText(String linkedItemId, LabelValueContext context) {
    final linkedItem = _itemsById[linkedItemId];
    final linkedValue = linkedItem?.labelValue;
    if (linkedItem == null ||
        linkedValue == null ||
        linkedValue.kind == ValueSourceKind.sameAsItem) {
      return '';
    }
    return resolve(linkedItem, context);
  }
}

int serialValueAt(SerialNumberRule rule, int start, int recordIndex) {
  final groupIndex = recordIndex ~/ _repeatEveryAtLeastOne(rule);
  return start + groupIndex * rule.step * _direction(rule);
}

String serialNumberText(SerialNumberRule rule, int start, int recordIndex) {
  final value = serialValueAt(rule, start, recordIndex);
  final digits = value.abs().toString().padLeft(rule.minDigits, '0');
  return value < 0 ? '-$digits' : digits;
}

int serialStartAfterPrinting(
  SerialNumberRule rule,
  int start,
  int recordCount,
) {
  final repeatEvery = _repeatEveryAtLeastOne(rule);
  final groupsUsed = (recordCount + repeatEvery - 1) ~/ repeatEvery;
  return start + groupsUsed * rule.step * _direction(rule);
}

int _repeatEveryAtLeastOne(SerialNumberRule rule) {
  return rule.repeatEvery < 1 ? 1 : rule.repeatEvery;
}

int _direction(SerialNumberRule rule) => rule.countDown ? -1 : 1;

String dateText(DateRule rule, DateTime today) {
  return DateFormat(
    rule.pattern,
  ).format(today.add(Duration(days: rule.addDays)));
}
