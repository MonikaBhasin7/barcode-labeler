import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../../core/settings/app_settings_store.dart';
import '../../../design/data/models/barcode_type.dart';
import '../../../design/data/models/label_font.dart';
import '../../../design/data/models/label_item.dart';
import '../../application/designer_controller.dart';
import 'property_fields.dart';
import 'value_source_editor.dart';

const double propertiesPanelWidth = 340;

class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({
    super.key,
    required this.controller,
    required this.onReplacePicture,
  });

  final DesignerController controller;
  final ValueChanged<PictureItem> onReplacePicture;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: propertiesPanelWidth,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Obx(() {
          final item = controller.selectedItem;
          final design = controller.design.value;
          final dataTable = controller.dataTable.value;
          final unit = Get.find<AppSettingsStore>().lengthUnit.value;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (item == null)
                _NothingSelected(
                  items: design.items,
                  labelWidthMm: design.sheet.labelWidthMm,
                  labelHeightMm: design.sheet.labelHeightMm,
                  onSelectItem: controller.selectItem,
                  labelSize:
                      '${unit.format(design.sheet.labelWidthMm)} × '
                      '${unit.formatWithLabel(design.sheet.labelHeightMm)}',
                  labelsPerSheet: design.sheet.labelsPerSheet,
                  excelFileName: design.dataFile == null
                      ? null
                      : p.basename(design.dataFile!.path),
                  excelRowCount: dataTable?.rows.length,
                )
              else
                _ItemProperties(
                  key: ValueKey(item.id),
                  item: item,
                  controller: controller,
                  onReplacePicture: onReplacePicture,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _NothingSelected extends StatelessWidget {
  const _NothingSelected({
    required this.items,
    required this.labelWidthMm,
    required this.labelHeightMm,
    required this.onSelectItem,
    required this.labelSize,
    required this.labelsPerSheet,
    required this.excelFileName,
    required this.excelRowCount,
  });

  final List<LabelItem> items;
  final double labelWidthMm;
  final double labelHeightMm;
  final ValueChanged<String> onSelectItem;
  final String labelSize;
  final int labelsPerSheet;
  final String? excelFileName;
  final int? excelRowCount;

  bool _isOutsideLabel(ItemFrame frame) {
    return frame.x >= labelWidthMm ||
        frame.y >= labelHeightMm ||
        frame.x + frame.width <= 0 ||
        frame.y + frame.height <= 0;
  }

  IconData _iconFor(LabelItem item) => switch (item) {
    BarcodeItem(:final type) when type.isTwoDimensional => Icons.qr_code_2,
    BarcodeItem() => Icons.view_week_outlined,
    TextItem() => Icons.title,
    ShapeItem(shape: ShapeKind.line) => Icons.horizontal_rule,
    ShapeItem(shape: ShapeKind.ellipse) => Icons.circle_outlined,
    ShapeItem() => Icons.crop_square,
    PictureItem() => Icons.image_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final excelText = switch ((excelFileName, excelRowCount)) {
      (null, _) => 'No Excel file linked',
      (final name?, null) => '$name (not loaded)',
      (final name?, final rows?) => '$name · $rows rows',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This label', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Size: $labelSize'),
        Text('Labels on each sheet: $labelsPerSheet'),
        Text('Excel: $excelText'),
        const SizedBox(height: 24),
        Text('Items on this label', style: textTheme.titleMedium),
        const SizedBox(height: 4),
        if (items.isEmpty)
          const Text('Nothing yet.')
        else
          for (final item in items.reversed)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(_iconFor(item), size: 20),
              title: Text(item.name),
              subtitle: _isOutsideLabel(item.frame)
                  ? const Text(
                      'Outside the label',
                      style: TextStyle(color: Colors.red),
                    )
                  : null,
              onTap: () => onSelectItem(item.id),
            ),
        const SizedBox(height: 24),
        Text('How to use', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          '• Add text, barcodes and shapes from the left.\n'
          '• Click an item to change it here.\n'
          '• Drag an item to move it. Drag its small square to resize it.\n'
          '• Arrow keys move the selected item. Hold Shift to move it further.\n'
          '• Delete removes the selected item.',
        ),
      ],
    );
  }
}

class _ItemProperties extends StatelessWidget {
  const _ItemProperties({
    super.key,
    required this.item,
    required this.controller,
    required this.onReplacePicture,
  });

  final LabelItem item;
  final DesignerController controller;
  final ValueChanged<PictureItem> onReplacePicture;

  void _change(LabelItem changed, String field) {
    controller.replaceItem(changed, changeKey: '${item.id}:$field');
  }

  void _changeFrame(ItemFrame frame, String field) {
    _change(item.copyWithCommon(frame: frame), 'frame:$field');
  }

  @override
  Widget build(BuildContext context) {
    final frame = item.frame;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(item.kindLabel, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        PanelSection(
          title: 'Name',
          children: [
            SyncedTextField(
              label: 'Name',
              value: item.name,
              onChanged: (name) =>
                  _change(item.copyWithCommon(name: name), 'name'),
            ),
          ],
        ),
        PanelSection(
          title: 'Position and size',
          children: [
            FieldPair(
              first: LengthField(
                label: 'From left',
                valueMm: frame.x,
                onChangedMm: (x) => _changeFrame(frame.copyWith(x: x), 'x'),
              ),
              second: LengthField(
                label: 'From top',
                valueMm: frame.y,
                onChangedMm: (y) => _changeFrame(frame.copyWith(y: y), 'y'),
              ),
            ),
            FieldPair(
              first: LengthField(
                label: 'Width',
                valueMm: frame.width,
                minMm: 0.5,
                onChangedMm: (width) =>
                    _changeFrame(frame.copyWith(width: width), 'width'),
              ),
              second: LengthField(
                label: 'Height',
                valueMm: frame.height,
                minMm: 0.5,
                onChangedMm: (height) =>
                    _changeFrame(frame.copyWith(height: height), 'height'),
              ),
            ),
            SegmentedButton<QuarterTurn>(
              showSelectedIcon: false,
              segments: [
                for (final turn in QuarterTurn.values)
                  ButtonSegment(value: turn, label: Text(turn.label)),
              ],
              selected: {item.rotation},
              onSelectionChanged: (turns) => _change(
                item.copyWithCommon(rotation: turns.first),
                'rotation',
              ),
            ),
          ],
        ),
        ...switch (item) {
          final TextItem text => _textSections(text),
          final BarcodeItem barcode => _barcodeSections(context, barcode),
          final ShapeItem shape => _shapeSections(shape),
          final PictureItem picture => _pictureSections(picture),
        },
        PanelSection(
          title: 'Arrange',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Duplicate'),
                  onPressed: controller.duplicateSelectedItem,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.flip_to_front, size: 18),
                  label: const Text('To front'),
                  onPressed: controller.bringSelectedItemToFront,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.flip_to_back, size: 18),
                  label: const Text('To back'),
                  onPressed: controller.sendSelectedItemToBack,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: controller.deleteSelectedItem,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _textSections(TextItem text) {
    return [
      PanelSection(
        title: 'Value',
        children: [
          ValueSourceEditor(
            item: text,
            valueKey: text.id,
            value: text.value,
            controller: controller,
            onChanged: (value, field) =>
                _change(text.copyWith(value: value), 'value:$field'),
          ),
        ],
      ),
      PanelSection(
        title: 'Look',
        children: [
          DropdownField<LabelFont>(
            label: 'Font',
            value: text.font,
            options: LabelFont.values,
            optionLabel: (font) => font.label,
            optionStyle: (font) => TextStyle(fontFamily: font.familyName),
            onChanged: (font) => _change(text.copyWith(font: font), 'font'),
          ),
          FieldPair(
            first: NumberField(
              label: 'Text size',
              suffix: 'pt',
              value: text.fontSizePt,
              min: 1,
              max: 500,
              onChanged: (size) =>
                  _change(text.copyWith(fontSizePt: size), 'fontSize'),
            ),
            second: FilterChip(
              label: const Text('Bold'),
              selected: text.bold,
              onSelected: (bold) => _change(text.copyWith(bold: bold), 'bold'),
            ),
          ),
          SegmentedButton<TextAlignment>(
            showSelectedIcon: false,
            segments: [
              for (final alignment in TextAlignment.values)
                ButtonSegment(value: alignment, label: Text(alignment.label)),
            ],
            selected: {text.alignment},
            onSelectionChanged: (choice) =>
                _change(text.copyWith(alignment: choice.first), 'alignment'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _barcodeSections(BuildContext context, BarcodeItem barcode) {
    return [
      PanelSection(
        title: 'Barcode',
        children: [
          DropdownField<BarcodeType>(
            label: 'Barcode type',
            value: barcode.type,
            options: BarcodeType.values,
            optionLabel: (type) => type.label,
            onChanged: (type) => _change(barcode.copyWith(type: type), 'type'),
          ),
          if (!barcode.type.isTwoDimensional)
            Text(
              'Leave empty space on the left and right of the bars, or '
              'scanners may not read it. If it does not scan, make it wider.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ValueSourceEditor(
            item: barcode,
            valueKey: barcode.id,
            value: barcode.value,
            controller: controller,
            onChanged: (value, field) =>
                _change(barcode.copyWith(value: value), 'value:$field'),
          ),
          if (!barcode.type.isTwoDimensional) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Show the number under the bars'),
              value: barcode.showText,
              onChanged: (show) =>
                  _change(barcode.copyWith(showText: show), 'showText'),
            ),
            if (barcode.showText)
              NumberField(
                label: 'Number size',
                suffix: 'pt',
                value: barcode.textSizePt,
                min: 1,
                max: 200,
                onChanged: (size) =>
                    _change(barcode.copyWith(textSizePt: size), 'textSize'),
              ),
          ],
        ],
      ),
    ];
  }

  List<Widget> _shapeSections(ShapeItem shape) {
    return [
      PanelSection(
        title: 'Shape',
        children: [
          SegmentedButton<ShapeKind>(
            showSelectedIcon: false,
            segments: [
              for (final kind in ShapeKind.values)
                ButtonSegment(value: kind, label: Text(kind.label)),
            ],
            selected: {shape.shape},
            onSelectionChanged: (kinds) =>
                _change(shape.copyWith(shape: kinds.first), 'shape'),
          ),
          LengthField(
            label: 'Line thickness',
            valueMm: shape.lineWidthMm,
            minMm: 0.05,
            maxMm: 50,
            extraDecimals: 1,
            onChangedMm: (width) =>
                _change(shape.copyWith(lineWidthMm: width), 'lineWidth'),
          ),
          if (shape.shape != ShapeKind.line)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Fill with black'),
              value: shape.filled,
              onChanged: (filled) =>
                  _change(shape.copyWith(filled: filled), 'filled'),
            ),
        ],
      ),
    ];
  }

  List<Widget> _pictureSections(PictureItem picture) {
    return [
      PanelSection(
        title: 'Picture',
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.image_outlined),
            label: const Text('Replace picture…'),
            onPressed: () => onReplacePicture(picture),
          ),
        ],
      ),
    ];
  }
}
