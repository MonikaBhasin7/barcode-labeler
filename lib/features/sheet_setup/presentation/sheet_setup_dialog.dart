import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/settings/app_settings_store.dart';

import '../../design/application/sheet_geometry.dart';
import '../../design/data/models/label_design.dart';
import '../../designer/presentation/widgets/property_fields.dart';
import 'widgets/sheet_preview.dart';

Future<SheetLayout?> showSheetSetupDialog(
  BuildContext context,
  SheetLayout current,
) {
  return showDialog<SheetLayout>(
    context: context,
    builder: (_) => SheetSetupDialog(initialSheet: current),
  );
}

class SheetSetupDialog extends StatefulWidget {
  const SheetSetupDialog({super.key, required this.initialSheet});

  final SheetLayout initialSheet;

  @override
  State<SheetSetupDialog> createState() => _SheetSetupDialogState();
}

class _SheetSetupDialogState extends State<SheetSetupDialog> {
  late SheetLayout _sheet = widget.initialSheet;

  void _update(SheetLayout sheet) => setState(() => _sheet = sheet);

  void _choosePaper(PaperSize paper) {
    if (paper == PaperSize.custom) {
      _update(_sheet.copyWith(paper: paper));
      return;
    }
    _update(
      _sheet.copyWith(
        paper: paper,
        pageWidthMm: paper.widthMm,
        pageHeightMm: paper.heightMm,
      ),
    );
  }

  void _turnPageSideways() {
    _update(
      _sheet.copyWith(
        pageWidthMm: _sheet.pageHeightMm,
        pageHeightMm: _sheet.pageWidthMm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final problem = sheetLayoutProblem(
      _sheet,
      unit: Get.find<AppSettingsStore>().lengthUnit.value,
    );
    return AlertDialog(
      title: const Text('Sheet setup'),
      content: SizedBox(
        width: 860,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: SingleChildScrollView(child: _fields())),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SheetPreview(sheet: _sheet),
                  const SizedBox(height: 12),
                  Text('${_sheet.labelsPerSheet} labels on each sheet'),
                  if (problem != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        problem,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: problem == null
              ? () => Navigator.pop(context, _sheet)
              : null,
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _fields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelSection(
          title: 'Paper',
          children: [
            DropdownField<PaperSize>(
              label: 'Paper size',
              value: _sheet.paper,
              options: PaperSize.values,
              optionLabel: (paper) => paper.label,
              onChanged: _choosePaper,
            ),
            FieldPair(
              first: LengthField(
                label: 'Page width',
                valueMm: _sheet.pageWidthMm,
                minMm: 10,
                onChangedMm: (width) => _update(
                  _sheet.copyWith(paper: PaperSize.custom, pageWidthMm: width),
                ),
              ),
              second: LengthField(
                label: 'Page height',
                valueMm: _sheet.pageHeightMm,
                minMm: 10,
                onChangedMm: (height) => _update(
                  _sheet.copyWith(
                    paper: PaperSize.custom,
                    pageHeightMm: height,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.screen_rotation_alt, size: 18),
                label: const Text('Turn page sideways'),
                onPressed: _turnPageSideways,
              ),
            ),
          ],
        ),
        PanelSection(
          title: 'One label',
          children: [
            FieldPair(
              first: LengthField(
                label: 'Label width',
                valueMm: _sheet.labelWidthMm,
                minMm: 1,
                onChangedMm: (width) =>
                    _update(_sheet.copyWith(labelWidthMm: width)),
              ),
              second: LengthField(
                label: 'Label height',
                valueMm: _sheet.labelHeightMm,
                minMm: 1,
                onChangedMm: (height) =>
                    _update(_sheet.copyWith(labelHeightMm: height)),
              ),
            ),
          ],
        ),
        PanelSection(
          title: 'Labels on the sheet',
          children: [
            FieldPair(
              first: NumberField(
                label: 'Labels across',
                value: _sheet.columns.toDouble(),
                decimals: 0,
                min: 1,
                max: 100,
                onChanged: (columns) =>
                    _update(_sheet.copyWith(columns: columns.toInt())),
              ),
              second: NumberField(
                label: 'Labels down',
                value: _sheet.rows.toDouble(),
                decimals: 0,
                min: 1,
                max: 200,
                onChanged: (rows) =>
                    _update(_sheet.copyWith(rows: rows.toInt())),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => _update(withMostLabelsThatFit(_sheet)),
                  child: const Text('Fit as many as possible'),
                ),
                OutlinedButton(
                  onPressed: () => _update(withLabelFillingWholePage(_sheet)),
                  child: const Text('One label = whole page'),
                ),
              ],
            ),
            DropdownField<FillOrder>(
              label: 'Print order',
              value: _sheet.fillOrder,
              options: FillOrder.values,
              optionLabel: (order) => order.label,
              onChanged: (order) => _update(_sheet.copyWith(fillOrder: order)),
            ),
          ],
        ),
        PanelSection(
          title: 'Margins and gaps',
          children: [
            FieldPair(
              first: LengthField(
                label: 'Top margin',
                valueMm: _sheet.marginTopMm,
                minMm: 0,
                onChangedMm: (margin) =>
                    _update(_sheet.copyWith(marginTopMm: margin)),
              ),
              second: LengthField(
                label: 'Left margin',
                valueMm: _sheet.marginLeftMm,
                minMm: 0,
                onChangedMm: (margin) =>
                    _update(_sheet.copyWith(marginLeftMm: margin)),
              ),
            ),
            FieldPair(
              first: LengthField(
                label: 'Gap between labels across',
                valueMm: _sheet.gapAcrossMm,
                minMm: 0,
                onChangedMm: (gap) =>
                    _update(_sheet.copyWith(gapAcrossMm: gap)),
              ),
              second: LengthField(
                label: 'Gap between labels down',
                valueMm: _sheet.gapDownMm,
                minMm: 0,
                onChangedMm: (gap) => _update(_sheet.copyWith(gapDownMm: gap)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
