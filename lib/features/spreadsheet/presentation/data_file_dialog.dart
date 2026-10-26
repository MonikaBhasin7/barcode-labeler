import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../design/data/models/label_design.dart';
import '../../designer/presentation/widgets/property_fields.dart';
import '../data/models/spreadsheet_table.dart';
import '../data/spreadsheet_reader.dart';

const int _previewRowLimit = 50;

class DataFileChoice {
  const DataFileChoice.use(DataFileLink this.link, SpreadsheetTable this.table);

  const DataFileChoice.removeLink() : link = null, table = null;

  final DataFileLink? link;
  final SpreadsheetTable? table;
}

Future<DataFileChoice?> showDataFileDialog(
  BuildContext context, {
  required DataFileLink? current,
  required SpreadsheetReader reader,
}) {
  return showDialog<DataFileChoice>(
    context: context,
    builder: (_) => DataFileDialog(current: current, reader: reader),
  );
}

class DataFileDialog extends StatefulWidget {
  const DataFileDialog({
    super.key,
    required this.current,
    required this.reader,
  });

  final DataFileLink? current;
  final SpreadsheetReader reader;

  @override
  State<DataFileDialog> createState() => _DataFileDialogState();
}

class _DataFileDialogState extends State<DataFileDialog> {
  String? _path;
  List<String> _sheetNames = const [];
  String? _sheetName;
  SpreadsheetTable? _table;
  String? _problem;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    if (current != null) _openFile(current.path, current.sheetName);
  }

  Future<void> _chooseFile() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose the Excel file',
      type: FileType.custom,
      allowedExtensions: spreadsheetFileExtensions,
    );
    final path = file?.path;
    if (path != null) await _openFile(path, null);
  }

  Future<void> _openFile(String path, String? preferredSheet) async {
    setState(() {
      _path = path;
      _loading = true;
      _problem = null;
      _table = null;
    });
    try {
      final sheetNames = await widget.reader.readSheetNames(path);
      final sheetName = sheetNames.contains(preferredSheet)
          ? preferredSheet!
          : sheetNames.first;
      final table = await widget.reader.readTable(path, sheetName);
      if (!mounted) return;
      setState(() {
        _sheetNames = sheetNames;
        _sheetName = sheetName;
        _table = table;
      });
    } on SpreadsheetReadException catch (error) {
      if (mounted) setState(() => _problem = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseSheet(String sheetName) async {
    final path = _path;
    if (path == null) return;
    setState(() {
      _sheetName = sheetName;
      _loading = true;
      _problem = null;
    });
    try {
      final table = await widget.reader.readTable(path, sheetName);
      if (mounted) setState(() => _table = table);
    } on SpreadsheetReadException catch (error) {
      if (mounted) setState(() => _problem = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _useThisFile() {
    final path = _path;
    final sheetName = _sheetName;
    final table = _table;
    if (path == null || sheetName == null || table == null) return;
    Navigator.pop(
      context,
      DataFileChoice.use(DataFileLink(path: path, sheetName: sheetName), table),
    );
  }

  @override
  Widget build(BuildContext context) {
    final table = _table;
    return AlertDialog(
      title: const Text('Excel data'),
      content: SizedBox(
        width: 900,
        height: 540,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Choose Excel file…'),
                  onPressed: _loading ? null : _chooseFile,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _path == null
                        ? 'Choose an .xlsx or .csv file. Its first row must '
                              'have the column names.'
                        : p.basename(_path!),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_sheetNames.length > 1 && _sheetName != null)
                  SizedBox(
                    width: 220,
                    child: DropdownField<String>(
                      label: 'Sheet',
                      value: _sheetName!,
                      options: _sheetNames,
                      optionLabel: (name) => name,
                      onChanged: _chooseSheet,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_problem != null)
              Text(_problem!, style: const TextStyle(color: Colors.red)),
            if (table != null) ...[
              Text(
                '${table.rows.length} rows · ${table.headers.length} columns'
                '${table.hiddenRowCount > 0 ? ' · ${table.hiddenRowCount} hidden rows are left out' : ''}'
                '${table.rows.length > _previewRowLimit ? ' · showing the first $_previewRowLimit rows' : ''}',
              ),
              const SizedBox(height: 8),
              Expanded(child: _TablePreview(table: table)),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const DataFileChoice.removeLink()),
            child: const Text('Remove Excel link'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: table == null || table.headers.isEmpty
              ? null
              : _useThisFile,
          child: const Text('Use this file'),
        ),
      ],
    );
  }
}

class _TablePreview extends StatefulWidget {
  const _TablePreview({required this.table});

  final SpreadsheetTable table;

  @override
  State<_TablePreview> createState() => _TablePreviewState();
}

class _TablePreviewState extends State<_TablePreview> {
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Scrollbar(
        controller: _vertical,
        thumbVisibility: true,
        child: Scrollbar(
          controller: _horizontal,
          thumbVisibility: true,
          notificationPredicate: (notification) => notification.depth == 1,
          child: SingleChildScrollView(
            controller: _vertical,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 30,
                dataRowMaxHeight: 30,
                columns: [
                  const DataColumn(label: Text('Excel row')),
                  for (final header in table.headers)
                    DataColumn(label: Text(header)),
                ],
                rows: [
                  for (final (index, row)
                      in table.rows.take(_previewRowLimit).indexed)
                    DataRow(
                      cells: [
                        DataCell(Text('${table.excelRowNumbers[index]}')),
                        for (final header in table.headers)
                          DataCell(Text(row[header] ?? '')),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
