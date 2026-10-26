import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/ids.dart';
import '../../../design/application/label_value_resolver.dart';
import '../../../design/data/models/label_design.dart';
import '../../../design/data/models/label_item.dart';
import '../../../design/data/models/label_value.dart';
import '../../application/designer_controller.dart';
import 'property_fields.dart';

typedef LabelValueChanged = void Function(LabelValue value, String field);

class ValueSourceEditor extends StatelessWidget {
  const ValueSourceEditor({
    super.key,
    required this.item,
    required this.valueKey,
    required this.value,
    required this.controller,
    required this.onChanged,
    this.allowedKinds = ValueSourceKind.values,
    this.isPartOfJoinedValue = false,
  });

  final LabelItem item;
  final String valueKey;
  final LabelValue value;
  final DesignerController controller;
  final LabelValueChanged onChanged;
  final List<ValueSourceKind> allowedKinds;
  final bool isPartOfJoinedValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        DropdownField<ValueSourceKind>(
          label: 'Value comes from',
          value: value.kind,
          options: [
            if (!allowedKinds.contains(value.kind)) value.kind,
            ...allowedKinds,
          ],
          optionLabel: (kind) => kind.label,
          onChanged: _changeKind,
        ),
        ...switch (value.kind) {
          ValueSourceKind.fixedText => [_fixedTextField()],
          ValueSourceKind.excelColumn => [_excelColumnField()],
          ValueSourceKind.serialNumber => _serialNumberFields(context),
          ValueSourceKind.date => _dateFields(),
          ValueSourceKind.typedWhenPrinting => _questionFields(context),
          ValueSourceKind.joinedParts => _joinedPartsFields(context),
          ValueSourceKind.sameAsItem => [_linkedItemField(context)],
        },
        if (!isPartOfJoinedValue &&
            value.kind != ValueSourceKind.sameAsItem &&
            value.kind != ValueSourceKind.joinedParts)
          FieldPair(
            first: SyncedTextField(
              label: 'Text before',
              value: value.prefix,
              onChanged: (prefix) =>
                  onChanged(value.copyWith(prefix: prefix), 'prefix'),
            ),
            second: SyncedTextField(
              label: 'Text after',
              value: value.suffix,
              onChanged: (suffix) =>
                  onChanged(value.copyWith(suffix: suffix), 'suffix'),
            ),
          ),
      ],
    );
  }

  void _changeKind(ValueSourceKind kind) {
    if (kind == ValueSourceKind.joinedParts && value.parts.isEmpty) {
      final firstPart = ValuePart(
        id: newRandomId(),
        value: partValueKinds.contains(value.kind)
            ? value.copyWith(prefix: '', suffix: '')
            : const LabelValue(),
      );
      onChanged(value.copyWith(kind: kind, parts: [firstPart]), 'kind');
      return;
    }
    onChanged(value.copyWith(kind: kind), 'kind');
  }

  List<Widget> _questionFields(BuildContext context) {
    return [
      SyncedTextField(
        label: 'Question to ask when printing',
        hint: 'For example: Batch number?',
        value: value.question,
        onChanged: (question) =>
            onChanged(value.copyWith(question: question), 'question'),
      ),
      Text(
        'The print screen asks this question. The answer goes on every '
        'label of that print.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  List<Widget> _joinedPartsFields(BuildContext context) {
    final parts = value.parts;
    return [
      for (final (index, part) in parts.indexed)
        _PartCard(
          number: index + 1,
          canMoveUp: index > 0,
          canMoveDown: index < parts.length - 1,
          canRemove: parts.length > 1,
          onMoveUp: () => _swapParts(index, index - 1),
          onMoveDown: () => _swapParts(index, index + 1),
          onRemove: () => _replaceParts([...parts]..removeAt(index), 'remove'),
          child: ValueSourceEditor(
            item: item,
            valueKey: partValueKey(item.id, part.id),
            value: part.value,
            controller: controller,
            allowedKinds: partValueKinds,
            isPartOfJoinedValue: true,
            onChanged: (partValue, field) => _replaceParts([
              for (final existing in parts)
                existing.id == part.id
                    ? existing.copyWith(value: partValue)
                    : existing,
            ], '${part.id}:$field'),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add a part'),
          onPressed: () => _replaceParts([
            ...parts,
            ValuePart(id: newRandomId(), value: const LabelValue()),
          ], 'add'),
        ),
      ),
      Text(
        'The parts are joined in this order, with nothing between them.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  void _swapParts(int from, int to) {
    final parts = [...value.parts];
    final moving = parts[from];
    parts[from] = parts[to];
    parts[to] = moving;
    _replaceParts(parts, 'order');
  }

  void _replaceParts(List<ValuePart> parts, String field) {
    onChanged(value.copyWith(parts: parts), 'parts:$field');
  }

  Widget _fixedTextField() {
    return SyncedTextField(
      label: item is BarcodeItem && !isPartOfJoinedValue
          ? 'Barcode value'
          : 'Text',
      value: value.fixedText,
      multiline: item is TextItem,
      onChanged: (text) => onChanged(value.copyWith(fixedText: text), 'fixed'),
    );
  }

  Widget _excelColumnField() {
    return Obx(() {
      final columns = controller.availableColumns;
      if (columns.isEmpty) {
        return SyncedTextField(
          label: 'Excel column name',
          hint: 'Link an Excel file to pick from a list',
          value: value.excelColumn,
          onChanged: (column) =>
              onChanged(value.copyWith(excelColumn: column), 'column'),
        );
      }
      final options = [
        if (!columns.contains(value.excelColumn)) value.excelColumn,
        ...columns,
      ];
      final firstRowValue = controller.previewRow[value.excelColumn];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownField<String>(
            label: 'Excel column',
            value: value.excelColumn,
            options: options,
            optionLabel: (column) =>
                column.isEmpty ? 'Choose a column' : column,
            onChanged: (column) =>
                onChanged(value.copyWith(excelColumn: column), 'column'),
          ),
          if (firstRowValue != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Row 1: $firstRowValue'),
            ),
        ],
      );
    });
  }

  List<Widget> _serialNumberFields(BuildContext context) {
    final serial = value.serial;
    void changeSerial(SerialNumberRule rule, String field) {
      onChanged(value.copyWith(serial: rule), 'serial:$field');
    }

    final examples = [
      for (var index = 0; index < 4; index++)
        serialNumberText(serial, serial.start, index),
    ].join(', ');
    return [
      FieldPair(
        first: NumberField(
          label: 'Start at',
          value: serial.start.toDouble(),
          decimals: 0,
          onChanged: (start) =>
              changeSerial(serial.copyWith(start: start.toInt()), 'start'),
        ),
        second: NumberField(
          label: 'Step',
          value: serial.step.toDouble(),
          decimals: 0,
          min: 1,
          onChanged: (step) =>
              changeSerial(serial.copyWith(step: step.toInt()), 'step'),
        ),
      ),
      FieldPair(
        first: NumberField(
          label: 'Repeat each number',
          suffix: 'times',
          value: serial.repeatEvery.toDouble(),
          decimals: 0,
          min: 1,
          onChanged: (times) => changeSerial(
            serial.copyWith(repeatEvery: times.toInt()),
            'repeat',
          ),
        ),
        second: NumberField(
          label: 'Fill with zeros to',
          suffix: 'digits',
          value: serial.minDigits.toDouble(),
          decimals: 0,
          min: 0,
          max: 30,
          onChanged: (digits) => changeSerial(
            serial.copyWith(minDigits: digits.toInt()),
            'digits',
          ),
        ),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('Count down instead of up'),
        value: serial.countDown,
        onChanged: (countDown) => changeSerial(
          serial.copyWith(countDown: countDown ?? false),
          'direction',
        ),
      ),
      Text(
        'Example: $examples …\n${_nextPrintText(serial)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  String _nextPrintText(SerialNumberRule serial) {
    final saved = controller.savedSerialStart(valueKey);
    if (saved == null) {
      return 'Each print carries on from where the last print ended.';
    }
    return 'The next print starts at ${serialNumberText(serial, saved, 0)}, '
        'carrying on from the last print. You can change it on the print '
        'screen.';
  }

  List<Widget> _dateFields() {
    final date = value.date;
    final now = DateTime.now();
    return [
      DropdownField<String>(
        label: 'Date format',
        value: date.pattern,
        options: [
          if (!datePatternChoices.contains(date.pattern)) date.pattern,
          ...datePatternChoices,
        ],
        optionLabel: (pattern) => DateFormat(pattern).format(now),
        onChanged: (pattern) => onChanged(
          value.copyWith(date: date.copyWith(pattern: pattern)),
          'date:pattern',
        ),
      ),
      NumberField(
        label: 'Add days (for expiry dates)',
        value: date.addDays.toDouble(),
        decimals: 0,
        onChanged: (days) => onChanged(
          value.copyWith(date: date.copyWith(addDays: days.toInt())),
          'date:days',
        ),
      ),
    ];
  }

  Widget _linkedItemField(BuildContext context) {
    final candidates = [
      for (final other in controller.design.value.items)
        if (other.id != item.id &&
            other.labelValue != null &&
            other.labelValue!.kind != ValueSourceKind.sameAsItem)
          other,
    ];
    if (candidates.isEmpty) {
      return Text(
        'Add another text or barcode first. This item will then copy its value.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final ids = [for (final candidate in candidates) candidate.id];
    final namesById = {
      for (final candidate in candidates) candidate.id: candidate.name,
    };
    return DropdownField<String>(
      label: 'Copy the value of',
      value: value.sameAsItemId,
      options: [
        if (!ids.contains(value.sameAsItemId)) value.sameAsItemId,
        ...ids,
      ],
      optionLabel: (id) => namesById[id] ?? 'Choose an item',
      onChanged: (id) => onChanged(value.copyWith(sameAsItemId: id), 'link'),
    );
  }
}

class _PartCard extends StatelessWidget {
  const _PartCard({
    required this.number,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    required this.child,
  });

  final int number;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Part $number',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Move up',
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: canMoveUp ? onMoveUp : null,
                ),
                IconButton(
                  tooltip: 'Move down',
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: canMoveDown ? onMoveDown : null,
                ),
                IconButton(
                  tooltip: 'Remove this part',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: canRemove ? onRemove : null,
                ),
              ],
            ),
            Padding(padding: const EdgeInsets.only(right: 6), child: child),
          ],
        ),
      ),
    );
  }
}
