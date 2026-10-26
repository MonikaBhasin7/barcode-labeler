import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/settings/app_settings_store.dart';

class NumberField extends StatefulWidget {
  const NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffix,
    this.decimals = 1,
    this.min,
    this.max,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final String? suffix;
  final int decimals;
  final double? min;
  final double? max;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final TextEditingController _text = TextEditingController(
    text: _formatted(widget.value),
  );
  final FocusNode _focus = FocusNode();
  String? _problem;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_showTidyValueWhenLeaving);
  }

  @override
  void didUpdateWidget(NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final typedValue = double.tryParse(_text.text.trim());
    if (!_focus.hasFocus && typedValue != widget.value) {
      _text.text = _formatted(widget.value);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  String _formatted(double value) {
    if (widget.decimals == 0) return value.round().toString();
    final fixed = value.toStringAsFixed(widget.decimals);
    return fixed.contains('.')
        ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
        : fixed;
  }

  void _showTidyValueWhenLeaving() {
    if (_focus.hasFocus) return;
    _text.text = _formatted(widget.value);
    if (_problem != null) setState(() => _problem = null);
  }

  void _reportTypedValue(String text) {
    final trimmed = text.trim();
    final value = double.tryParse(trimmed);
    final problem = _problemWith(trimmed, value);
    if (problem != _problem) setState(() => _problem = problem);
    if (problem != null || value == null) return;
    widget.onChanged(widget.decimals == 0 ? value.roundToDouble() : value);
  }

  String? _problemWith(String text, double? value) {
    if (text.isEmpty) return 'Type a number';
    if (text.contains(',')) return 'Use a dot for decimals, no commas';
    if (value == null) return 'Numbers only';
    if (widget.min case final min? when value < min) {
      return 'At least ${_formatted(min)}';
    }
    if (widget.max case final max? when value > max) {
      return 'At most ${_formatted(max)}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _text,
      focusNode: _focus,
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffix,
        errorText: _problem,
      ),
      onChanged: _reportTypedValue,
    );
  }
}

class LengthField extends StatelessWidget {
  const LengthField({
    super.key,
    required this.label,
    required this.valueMm,
    required this.onChangedMm,
    this.minMm,
    this.maxMm,
    this.extraDecimals = 0,
  });

  final String label;
  final double valueMm;
  final ValueChanged<double> onChangedMm;
  final double? minMm;
  final double? maxMm;
  final int extraDecimals;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final unit = Get.find<AppSettingsStore>().lengthUnit.value;
      final minMm = this.minMm;
      final maxMm = this.maxMm;
      return NumberField(
        key: ValueKey(unit),
        label: label,
        value: unit.fromMm(valueMm),
        suffix: unit.label,
        decimals: unit.decimals + extraDecimals,
        min: minMm == null ? null : unit.fromMm(minMm),
        max: maxMm == null ? null : unit.fromMm(maxMm),
        onChanged: (value) => onChangedMm(unit.toMm(value)),
      );
    });
  }
}

class SyncedTextField extends StatefulWidget {
  const SyncedTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.multiline = false,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool multiline;

  @override
  State<SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<SyncedTextField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(SyncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _text.text != widget.value) {
      _text.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _text,
      focusNode: _focus,
      minLines: 1,
      maxLines: widget.multiline ? 4 : 1,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
      ),
      onChanged: widget.onChanged,
    );
  }
}

class PanelSection extends StatelessWidget {
  const PanelSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            child,
          ],
        ],
      ),
    );
  }
}

class FieldPair extends StatelessWidget {
  const FieldPair({super.key, required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 10),
        Expanded(child: second),
      ],
    );
  }
}

class DropdownField<T> extends StatelessWidget {
  const DropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T option) optionLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(optionLabel(option))),
      ],
      onChanged: (option) {
        if (option != null) onChanged(option);
      },
    );
  }
}
