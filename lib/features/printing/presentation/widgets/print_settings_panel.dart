import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

import '../../../designer/presentation/widgets/property_fields.dart';
import '../../../spreadsheet/data/spreadsheet_reader.dart';
import '../../../spreadsheet/presentation/data_file_dialog.dart';
import '../../application/print_controller.dart';
import 'row_picker_dialog.dart';

class PrintSettingsPanel extends StatelessWidget {
  const PrintSettingsPanel({
    super.key,
    required this.controller,
    required this.onPrint,
    required this.onSavePdf,
    required this.onPrintTestSheet,
  });

  final PrintController controller;
  final VoidCallback onPrint;
  final VoidCallback onSavePdf;
  final VoidCallback onPrintTestSheet;

  Future<void> _chooseExcelFile(BuildContext context) async {
    final designer = controller.designer;
    final choice = await showDataFileDialog(
      context,
      current: designer.design.value.dataFile,
      reader: const SpreadsheetReader(),
    );
    final link = choice?.link;
    final table = choice?.table;
    if (link != null && table != null) designer.linkDataFile(link, table);
  }

  Future<void> _pickRows(BuildContext context) async {
    final table = controller.designer.dataTable.value;
    if (table == null) return;
    final picked = await showRowPickerDialog(
      context,
      table: table,
      initiallyPicked: controller.pickedRowNumbers,
    );
    if (picked != null) controller.choosePickedRows(picked);
  }

  void _chooseRowChoice(BuildContext context, RowChoice choice) {
    controller.rowChoice.value = choice;
    if (choice == RowChoice.picked && controller.pickedRowNumbers.isEmpty) {
      _pickRows(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Obx(() {
          final canPrint =
              !controller.busy.value && controller.problems.isEmpty;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PanelSection(
                title: 'What to print',
                children: _whatToPrintFields(context),
              ),
              if (controller.design.printQuestions.isNotEmpty)
                PanelSection(
                  title: 'Type these values',
                  children: _questionFields(),
                ),
              if (controller.design.serialNumberSources.isNotEmpty)
                PanelSection(
                  title: 'Serial numbers',
                  children: _serialNumberFields(),
                ),
              PanelSection(title: 'Printer', children: _printerFields()),
              _summary(context),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Print'),
                onPressed: canPrint ? onPrint : null,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Save as PDF'),
                onPressed: canPrint ? onSavePdf : null,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.grid_on),
                label: const Text('Print a test sheet (label outlines only)'),
                onPressed: controller.busy.value ? null : onPrintTestSheet,
              ),
              if (controller.busy.value)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
            ],
          );
        }),
      ),
    );
  }

  List<Widget> _whatToPrintFields(BuildContext context) {
    final perSheet = controller.design.sheet.labelsPerSheet;
    return [
      if (controller.usesExcel)
        ..._excelRowFields(context)
      else
        NumberField(
          label: 'How many labels',
          value: controller.labelCountWithoutExcel.value.toDouble(),
          decimals: 0,
          min: 1,
          max: 100000,
          onChanged: (count) =>
              controller.labelCountWithoutExcel.value = count.toInt(),
        ),
      NumberField(
        label: 'Copies of each label',
        value: controller.copiesPerRecord.value.toDouble(),
        decimals: 0,
        min: 1,
        max: 1000,
        onChanged: (copies) =>
            controller.copiesPerRecord.value = copies.toInt(),
      ),
      const _Hint('Copies are exactly the same, with the same number.'),
      if (perSheet > 1) ...[
        NumberField(
          label: 'Start at label number (1 to $perSheet)',
          value: controller.startAtPosition.value.toDouble(),
          decimals: 0,
          min: 1,
          max: perSheet.toDouble(),
          onChanged: (position) =>
              controller.startAtPosition.value = position.toInt(),
        ),
        const _Hint('Use this to finish a sheet that is half used.'),
      ],
    ];
  }

  List<Widget> _excelRowFields(BuildContext context) {
    final link = controller.design.dataFile;
    final hasTable = controller.designer.dataTable.value != null;
    final choice = controller.rowChoice.value;
    return [
      Row(
        children: [
          const Icon(Icons.table_chart_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              link == null
                  ? 'No Excel file chosen'
                  : '${p.basename(link.path)} · ${link.sheetName}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (link != null)
            IconButton(
              tooltip: 'Read the Excel file again',
              icon: const Icon(Icons.refresh),
              onPressed: controller.designer.loadLinkedDataFile,
            ),
          TextButton(
            onPressed: () => _chooseExcelFile(context),
            child: Text(link == null ? 'Choose…' : 'Change…'),
          ),
        ],
      ),
      if (controller.designer.dataFileProblem.value case final problem?)
        Text(problem, style: const TextStyle(color: Colors.red)),
      if (hasTable) ...[
        _Hint(_rowsSummary()),
        SegmentedButton<RowChoice>(
          showSelectedIcon: false,
          segments: [
            for (final option in RowChoice.values)
              ButtonSegment(value: option, label: Text(option.label)),
          ],
          selected: {choice},
          onSelectionChanged: (options) =>
              _chooseRowChoice(context, options.first),
        ),
        if (choice == RowChoice.range)
          FieldPair(
            first: NumberField(
              label: 'From Excel row',
              value: controller.rowsFrom.value.toDouble(),
              decimals: 0,
              min: 1,
              onChanged: (row) => controller.rowsFrom.value = row.toInt(),
            ),
            second: NumberField(
              label: 'To Excel row',
              value: controller.rowsTo.value.toDouble(),
              decimals: 0,
              min: 1,
              onChanged: (row) => controller.rowsTo.value = row.toInt(),
            ),
          ),
        if (choice == RowChoice.picked)
          Row(
            children: [
              Expanded(
                child: Text(
                  '${controller.pickedRowNumbers.length} rows picked',
                ),
              ),
              OutlinedButton(
                onPressed: () => _pickRows(context),
                child: const Text('Pick rows…'),
              ),
            ],
          ),
      ],
    ];
  }

  String _rowsSummary() {
    final table = controller.designer.dataTable.value;
    if (table == null || table.rows.isEmpty) return 'The sheet has no rows.';
    final hidden = table.hiddenRowCount == 0
        ? ''
        : ' ${table.hiddenRowCount} hidden rows are left out.';
    return 'The sheet has ${table.rows.length} rows of data, Excel rows '
        '${table.firstExcelRow} to ${table.lastExcelRow}.$hidden';
  }

  List<Widget> _questionFields() {
    return [
      for (final question in controller.design.printQuestions)
        SyncedTextField(
          key: ValueKey(question.key),
          label: question.prompt,
          value: controller.typedAnswers[question.key] ?? '',
          onChanged: (answer) =>
              controller.changeTypedAnswer(question.key, answer),
        ),
      const _Hint('The same answer goes on every label of this print.'),
    ];
  }

  List<Widget> _serialNumberFields() {
    return [
      for (final source in controller.design.serialNumberSources) ...[
        NumberField(
          key: ValueKey(source.key),
          label: '${source.label} starts at',
          value: (controller.serialStarts[source.key] ?? source.rule.start)
              .toDouble(),
          decimals: 0,
          onChanged: (start) =>
              controller.changeSerialStart(source.key, start.toInt()),
        ),
        if (controller.isNewSerialInPrintedDesign(source.key))
          const Text(
            'This serial number is new, but this design has printed before. '
            'Check the start number so no number is printed twice.',
            style: TextStyle(color: Colors.red),
          )
        else
          _Hint(
            controller.savedSerialStart(source.key) == null
                ? 'First print of this design.'
                : 'Carries on from the last print.',
          ),
      ],
    ];
  }

  List<Widget> _printerFields() {
    final printers = controller.printers;
    final selected = controller.selectedPrinter.value;
    final offset = controller.offset.value;
    return [
      Row(
        children: [
          Expanded(
            child: printers.isEmpty || selected == null
                ? const _Hint(
                    'No printers found. Print will open the print window '
                    'instead.',
                  )
                : DropdownField<Printer>(
                    label: 'Printer',
                    value: selected,
                    options: printers,
                    optionLabel: (printer) => printer.isAvailable
                        ? printer.name
                        : '${printer.name} (offline or paused)',
                    onChanged: controller.choosePrinter,
                  ),
          ),
          IconButton(
            tooltip: 'Look for printers again',
            icon: const Icon(Icons.refresh),
            onPressed: controller.refreshPrinters,
          ),
        ],
      ),
      FieldPair(
        first: LengthField(
          label: 'Move print right',
          valueMm: offset.rightMm,
          minMm: -50,
          maxMm: 50,
          onChangedMm: (right) =>
              controller.changeOffset(offset.copyWith(rightMm: right)),
        ),
        second: LengthField(
          label: 'Move print down',
          valueMm: offset.downMm,
          minMm: -50,
          maxMm: 50,
          onChangedMm: (down) =>
              controller.changeOffset(offset.copyWith(downMm: down)),
        ),
      ),
      const _Hint(
        'Most printers print a little off. Print the test sheet on plain '
        'paper, hold it on a label sheet against the light, then move the '
        'print here. Use minus numbers to move left or up. This is saved '
        'for this printer.',
      ),
    ];
  }

  Widget _summary(BuildContext context) {
    final problems = controller.problems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${controller.labelsToPrint.value} labels · '
          '${controller.sheetsToPrint.value} sheets',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final problem in problems)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(problem, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodySmall);
  }
}
