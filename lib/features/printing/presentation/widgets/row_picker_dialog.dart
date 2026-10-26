import 'package:flutter/material.dart';

import '../../../spreadsheet/data/models/spreadsheet_table.dart';

const double _tickColumnWidth = 48;
const double _rowNumberColumnWidth = 80;
const double _dataColumnWidth = 170;
const double _rowHeight = 36;

Future<List<int>?> showRowPickerDialog(
  BuildContext context, {
  required SpreadsheetTable table,
  required List<int> initiallyPicked,
}) {
  return showDialog<List<int>>(
    context: context,
    builder: (_) =>
        RowPickerDialog(table: table, initiallyPicked: initiallyPicked),
  );
}

class RowPickerDialog extends StatefulWidget {
  const RowPickerDialog({
    super.key,
    required this.table,
    required this.initiallyPicked,
  });

  final SpreadsheetTable table;
  final List<int> initiallyPicked;

  @override
  State<RowPickerDialog> createState() => _RowPickerDialogState();
}

class _RowPickerDialogState extends State<RowPickerDialog> {
  late final Set<int> _picked = {...widget.initiallyPicked};
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  int get _rowCount => widget.table.rows.length;

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  void _toggle(int rowNumber) {
    setState(() {
      if (!_picked.remove(rowNumber)) _picked.add(rowNumber);
    });
  }

  void _tickAll() {
    setState(() => _picked.addAll(widget.table.excelRowNumbers));
  }

  void _untickAll() => setState(_picked.clear);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick rows to print'),
      content: SizedBox(
        width: 900,
        height: 540,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${_picked.length} of $_rowCount rows picked'),
                ),
                TextButton(onPressed: _tickAll, child: const Text('Tick all')),
                TextButton(
                  onPressed: _untickAll,
                  child: const Text('Untick all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: _table(context)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _picked.isEmpty
              ? null
              : () => Navigator.pop(context, _picked.toList()..sort()),
          child: Text('Use ${_picked.length} rows'),
        ),
      ],
    );
  }

  Widget _table(BuildContext context) {
    final headers = widget.table.headers;
    final tableWidth =
        _tickColumnWidth +
        _rowNumberColumnWidth +
        headers.length * _dataColumnWidth;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Scrollbar(
        controller: _horizontal,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                _headerRow(context, headers),
                const Divider(height: 1),
                Expanded(
                  child: Scrollbar(
                    controller: _vertical,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _vertical,
                      itemExtent: _rowHeight,
                      itemCount: _rowCount,
                      itemBuilder: (context, index) => _dataRow(index, headers),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerRow(BuildContext context, List<String> headers) {
    final style = Theme.of(context).textTheme.labelLarge;
    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          const SizedBox(width: _tickColumnWidth),
          SizedBox(
            width: _rowNumberColumnWidth,
            child: Text('Excel row', style: style),
          ),
          for (final header in headers)
            SizedBox(
              width: _dataColumnWidth,
              child: Text(
                header,
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _dataRow(int index, List<String> headers) {
    final row = widget.table.rows[index];
    final excelRow = widget.table.excelRowNumbers[index];
    return InkWell(
      onTap: () => _toggle(excelRow),
      child: Row(
        children: [
          SizedBox(
            width: _tickColumnWidth,
            child: Checkbox(
              value: _picked.contains(excelRow),
              onChanged: (_) => _toggle(excelRow),
            ),
          ),
          SizedBox(width: _rowNumberColumnWidth, child: Text('$excelRow')),
          for (final header in headers)
            SizedBox(
              width: _dataColumnWidth,
              child: Text(row[header] ?? '', overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}
