import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../core/settings/app_settings_store.dart';
import '../../design/data/design_file_store.dart';
import '../../design/data/models/label_design.dart';
import '../../designer/presentation/designer_screen.dart';
import '../../settings/presentation/settings_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.designPathToOpen});

  final String? designPathToOpen;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AppSettingsStore _settings = Get.find<AppSettingsStore>();
  final DesignFileStore _designFiles = const DesignFileStore();
  late List<String> _recentPaths = _settings.recentDesignPaths();

  @override
  void initState() {
    super.initState();
    final path = widget.designPathToOpen;
    if (path != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDesign(path));
    }
  }

  void _refreshRecentDesigns() {
    setState(() => _recentPaths = _settings.recentDesignPaths());
  }

  Future<void> _startNewDesign() async {
    await _showDesigner(LabelDesign.blank(), null, startWithSheetSetup: true);
  }

  Future<void> _pickAndOpenDesign() async {
    final path = await _designFiles.pickDesignToOpen();
    if (path != null) await _openDesign(path);
  }

  Future<void> _openDesign(String path) async {
    final LabelDesign design;
    try {
      design = await _designFiles.readDesign(path);
    } on FileSystemException {
      await _settings.forgetRecentDesign(path);
      _refreshRecentDesigns();
      _showProblem(
        '"${p.basename(path)}" was not found. It may have been moved.',
      );
      return;
    } on FormatException catch (error) {
      _showProblem('Could not open "${p.basename(path)}": ${error.message}');
      return;
    }
    await _settings.rememberRecentDesign(path);
    await _showDesigner(design, path);
  }

  Future<void> _forgetRecentDesign(String path) async {
    await _settings.forgetRecentDesign(path);
    _refreshRecentDesigns();
  }

  Future<void> _showDesigner(
    LabelDesign design,
    String? path, {
    bool startWithSheetSetup = false,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DesignerScreen(
          initialDesign: design,
          filePath: path,
          startWithSheetSetup: startWithSheetSetup,
        ),
      ),
    );
    if (mounted) _refreshRecentDesigns();
  }

  void _showProblem(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showSettingsDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(32),
            children: [
              Icon(
                Icons.view_week_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Barcode Labeler',
                style: textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Design barcode labels and print them from Excel.',
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('New design'),
                    onPressed: _startNewDesign,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Open design…'),
                    onPressed: _pickAndOpenDesign,
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Text('Recent designs', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_recentPaths.isEmpty)
                const Text('No designs yet. Start with "New design".')
              else
                for (final path in _recentPaths)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(p.basenameWithoutExtension(path)),
                      subtitle: Text(
                        p.dirname(path),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove from this list',
                        icon: const Icon(Icons.close),
                        onPressed: () => _forgetRecentDesign(path),
                      ),
                      onTap: () => _openDesign(path),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
