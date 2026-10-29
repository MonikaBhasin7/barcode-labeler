import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';

import '../../../core/fonts/installed_fonts.dart';
import '../../../core/settings/app_settings_store.dart';
import '../../designer/application/designer_controller.dart';
import '../application/print_controller.dart';
import 'widgets/print_settings_panel.dart';

class PrintScreen extends StatefulWidget {
  const PrintScreen({super.key, required this.designer});

  final DesignerController designer;

  @override
  State<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends State<PrintScreen> {
  late final PrintController _controller = PrintController(
    designer: widget.designer,
    settings: Get.find<AppSettingsStore>(),
    installedFonts: Get.find<InstalledFonts>(),
  );

  @override
  void initState() {
    super.initState();
    _controller.onInit();
  }

  @override
  void dispose() {
    _controller.onClose();
    super.dispose();
  }

  void _showOutcome(PrintOutcome outcome) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(outcome.message),
        backgroundColor: outcome.succeeded ? null : Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text('Print · ${_controller.design.name}')),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrintSettingsPanel(
            controller: _controller,
            onPrint: () async => _showOutcome(await _controller.printLabels()),
            onSavePdf: () async => _showOutcome(await _controller.saveAsPdf()),
            onPrintTestSheet: () async =>
                _showOutcome(await _controller.printAlignmentTest()),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _PreviewArea(controller: _controller)),
        ],
      ),
    );
  }
}

class _PreviewArea extends StatelessWidget {
  const _PreviewArea({required this.controller});

  final PrintController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pdf = controller.previewPdf.value;
      final sheets = controller.sheetsToPrint.value;
      final building = controller.buildingPreview.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 4,
            child: building ? const LinearProgressIndicator() : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              sheets > previewSheetLimit
                  ? 'Preview of the first $previewSheetLimit of $sheets sheets'
                  : 'Preview',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: pdf == null
                ? Center(
                    child: Text(
                      building ? 'Making the preview…' : 'Nothing to show yet.',
                    ),
                  )
                : PdfPreview(
                    key: ValueKey(controller.previewVersion.value),
                    build: (_) async => pdf,
                    useActions: false,
                    allowPrinting: false,
                    allowSharing: false,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    maxPageWidth: 720,
                  ),
          ),
        ],
      );
    });
  }
}
