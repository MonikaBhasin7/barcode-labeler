import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../core/fonts/installed_fonts.dart';
import '../../../core/settings/app_settings_store.dart';
import '../../design/data/design_file_store.dart';
import '../../design/data/models/label_design.dart';
import '../../design/data/models/label_item.dart';
import '../../printing/presentation/print_screen.dart';
import '../../settings/presentation/settings_dialog.dart';
import '../../sheet_setup/presentation/sheet_setup_dialog.dart';
import '../../spreadsheet/data/spreadsheet_reader.dart';
import '../../spreadsheet/presentation/data_file_dialog.dart';
import '../application/designer_controller.dart';
import '../application/picture_picker.dart';
import 'widgets/add_item_bar.dart';
import 'widgets/label_canvas.dart';
import 'widgets/properties_panel.dart';

class DesignerScreen extends StatefulWidget {
  const DesignerScreen({
    super.key,
    required this.initialDesign,
    this.filePath,
    this.startWithSheetSetup = false,
  });

  final LabelDesign initialDesign;
  final String? filePath;
  final bool startWithSheetSetup;

  @override
  State<DesignerScreen> createState() => _DesignerScreenState();
}

class _DesignerScreenState extends State<DesignerScreen> {
  late final DesignerController _controller = DesignerController(
    initialDesign: widget.initialDesign,
    initialFilePath: widget.filePath,
    designFiles: const DesignFileStore(),
    spreadsheets: const SpreadsheetReader(),
    settings: Get.find<AppSettingsStore>(),
    installedFonts: Get.find<InstalledFonts>(),
  );
  late final AppLifecycleListener _appLifecycle;

  @override
  void initState() {
    super.initState();
    _controller.onInit();
    _appLifecycle = AppLifecycleListener(
      onExitRequested: _answerAppExitRequest,
    );
    _controller.loadLinkedDataFile();
    if (widget.startWithSheetSetup) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openSheetSetup());
    }
  }

  @override
  void dispose() {
    _appLifecycle.dispose();
    _controller.onClose();
    super.dispose();
  }

  Future<AppExitResponse> _answerAppExitRequest() async {
    final canLeave = await _confirmLeavingUnsavedChanges();
    return canLeave ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  Future<bool> _confirmLeavingUnsavedChanges() async {
    if (!_controller.hasUnsavedChanges.value) return true;
    final choice = await showDialog<_UnsavedChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Save changes to "${_controller.design.value.name}"?'),
        content: const Text('Your changes will be lost if you do not save.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _UnsavedChoice.stay),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _UnsavedChoice.discard),
            child: const Text('Don\'t save'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _UnsavedChoice.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return switch (choice) {
      _UnsavedChoice.discard => true,
      _UnsavedChoice.save => _save(),
      _UnsavedChoice.stay || null => false,
    };
  }

  Future<void> _leaveScreen() async {
    final canLeave = await _confirmLeavingUnsavedChanges();
    if (canLeave && mounted) Navigator.pop(context);
  }

  Future<bool> _save() async {
    try {
      return await _controller.save();
    } on FileSystemException catch (error) {
      _showMessage('Could not save: ${error.message}', isProblem: true);
      return false;
    }
  }

  Future<void> _saveAs() async {
    try {
      await _controller.saveAs();
    } on FileSystemException catch (error) {
      _showMessage('Could not save: ${error.message}', isProblem: true);
    }
  }

  Future<void> _openSheetSetup() async {
    final sheet = await showSheetSetupDialog(
      context,
      _controller.design.value.sheet,
    );
    if (sheet != null) _controller.updateSheet(sheet);
  }

  Future<void> _openExcelData() async {
    final choice = await showDataFileDialog(
      context,
      current: _controller.design.value.dataFile,
      reader: _controller.spreadsheets,
    );
    if (choice == null) return;
    final link = choice.link;
    final table = choice.table;
    if (link == null || table == null) {
      _controller.unlinkDataFile();
    } else {
      _controller.linkDataFile(link, table);
    }
  }

  Future<void> _openPrint() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PrintScreen(designer: _controller),
      ),
    );
  }

  Future<void> _addPicture() async {
    try {
      final picture = await pickPictureFromDisk();
      if (picture == null) return;
      _controller.addPictureItem(picture.bytes, picture.widthOverHeight);
    } on PictureReadException catch (error) {
      _showMessage(error.message, isProblem: true);
    }
  }

  Future<void> _replacePicture(PictureItem item) async {
    try {
      final picture = await pickPictureFromDisk();
      if (picture == null) return;
      _controller.replaceItem(item.copyWith(imageBytes: picture.bytes));
    } on PictureReadException catch (error) {
      _showMessage(error.message, isProblem: true);
    }
  }

  void _showMessage(String message, {bool isProblem = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isProblem ? Colors.red.shade700 : null,
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _keyboardShortcuts() {
    final onMac = Platform.isMacOS;
    SingleActivator command(LogicalKeyboardKey key, {bool shift = false}) {
      return SingleActivator(key, control: !onMac, meta: onMac, shift: shift);
    }

    return {
      command(LogicalKeyboardKey.keyS): _save,
      command(LogicalKeyboardKey.keyP): _openPrint,
      command(LogicalKeyboardKey.keyZ): _undoUnlessTyping,
      command(LogicalKeyboardKey.keyZ, shift: true): _redoUnlessTyping,
      command(LogicalKeyboardKey.keyY): _redoUnlessTyping,
    };
  }

  bool get _isTypingInTextField {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _undoUnlessTyping() {
    if (!_isTypingInTextField) _controller.undo();
  }

  void _redoUnlessTyping() {
    if (!_isTypingInTextField) _controller.redo();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveScreen();
      },
      child: CallbackShortcuts(
        bindings: _keyboardShortcuts(),
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: _appBar(),
            body: Column(
              children: [
                _DataFileProblemBanner(
                  controller: _controller,
                  onChooseFile: _openExcelData,
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AddItemBar(
                        controller: _controller,
                        onAddPicture: _addPicture,
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: LabelCanvas(controller: _controller)),
                      const VerticalDivider(width: 1),
                      PropertiesPanel(
                        controller: _controller,
                        onReplacePicture: _replacePicture,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      leading: BackButton(onPressed: _leaveScreen),
      title: Obx(() {
        final unsaved = _controller.hasUnsavedChanges.value ? ' •' : '';
        final path = _controller.filePath.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_controller.design.value.name}$unsaved'),
            Text(
              path == null ? 'Not saved yet' : p.dirname(path),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }),
      actions: [
        Obx(
          () => IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: _controller.canUndo.value ? _controller.undo : null,
          ),
        ),
        Obx(
          () => IconButton(
            tooltip: 'Redo',
            icon: const Icon(Icons.redo),
            onPressed: _controller.canRedo.value ? _controller.redo : null,
          ),
        ),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => showSettingsDialog(context),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          icon: const Icon(Icons.grid_view),
          label: const Text('Sheet setup'),
          onPressed: _openSheetSetup,
        ),
        TextButton.icon(
          icon: const Icon(Icons.table_chart_outlined),
          label: const Text('Excel data'),
          onPressed: _openExcelData,
        ),
        TextButton.icon(
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save'),
          onPressed: _save,
        ),
        TextButton(onPressed: _saveAs, child: const Text('Save as…')),
        const SizedBox(width: 8),
        FilledButton.icon(
          icon: const Icon(Icons.print),
          label: const Text('Print'),
          onPressed: _openPrint,
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

enum _UnsavedChoice { save, discard, stay }

class _DataFileProblemBanner extends StatelessWidget {
  const _DataFileProblemBanner({
    required this.controller,
    required this.onChooseFile,
  });

  final DesignerController controller;
  final VoidCallback onChooseFile;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final problem = controller.dataFileProblem.value;
      if (problem == null) return const SizedBox.shrink();
      return Material(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'The linked Excel file could not be read. $problem',
                ),
              ),
              TextButton(
                onPressed: onChooseFile,
                child: const Text('Choose the file'),
              ),
            ],
          ),
        ),
      );
    });
  }
}
