import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/settings/app_settings_store.dart';
import '../../../core/units.dart';

Future<void> showSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const SettingsDialog(),
  );
}

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  String _unitName(LengthUnit unit) => switch (unit) {
    LengthUnit.mm => 'Millimetres (mm)',
    LengthUnit.cm => 'Centimetres (cm)',
    LengthUnit.inch => 'Inches (in)',
  };

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsStore>();
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 460,
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Units for sizes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<LengthUnit>(
                showSelectedIcon: false,
                segments: [
                  for (final unit in LengthUnit.values)
                    ButtonSegment(value: unit, label: Text(_unitName(unit))),
                ],
                selected: {settings.lengthUnit.value},
                onSelectionChanged: (units) =>
                    settings.chooseLengthUnit(units.first),
              ),
              const SizedBox(height: 8),
              Text(
                'Designs are always saved the same way inside, so changing '
                'the units never moves anything.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
