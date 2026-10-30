import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';

import '../../../core/file_names.dart';
import '../../../core/fonts/installed_fonts.dart';
import '../../../core/settings/app_settings_store.dart';
import '../../design/application/label_value_resolver.dart';
import '../../design/data/models/label_design.dart';
import '../../design/data/models/label_font.dart';
import '../../designer/application/designer_controller.dart';
import '../data/models/printer_offset.dart';
import 'label_print_request.dart';
import 'label_sheets_pdf.dart';

const int previewSheetLimit = 3;
const String excelChangedMessage =
    'The Excel file was changed, so the new rows are now loaded. Check the '
    'preview, then press the button again.';

enum RowChoice {
  all('All rows'),
  range('From – to'),
  picked('Pick rows');

  const RowChoice(this.label);

  final String label;
}

class PrintOutcome {
  const PrintOutcome.succeeded(this.message) : succeeded = true;

  const PrintOutcome.failed(this.message) : succeeded = false;

  final bool succeeded;
  final String message;
}

class _ChosenRecords {
  const _ChosenRecords({required this.rows, required this.numbers});

  final List<Map<String, String>> rows;
  final List<int> numbers;
}

class PrintController extends GetxController {
  PrintController({
    required this.designer,
    required this.settings,
    required this.installedFonts,
  });

  final DesignerController designer;
  final AppSettingsStore settings;
  final InstalledFonts installedFonts;

  final Rx<RowChoice> rowChoice = RowChoice.all.obs;
  final RxInt rowsFrom = 1.obs;
  final RxInt rowsTo = 1.obs;
  final RxList<int> pickedRowNumbers = <int>[].obs;
  final RxInt labelCountWithoutExcel = 1.obs;
  final RxInt copiesPerRecord = 1.obs;
  final RxInt startAtPosition = 1.obs;
  final RxMap<String, int> serialStarts = <String, int>{}.obs;
  final RxMap<String, String> typedAnswers = <String, String>{}.obs;
  final RxList<Printer> printers = <Printer>[].obs;
  final Rxn<Printer> selectedPrinter = Rxn<Printer>();
  final Rx<PrinterOffset> offset = PrinterOffset.none.obs;
  final Rxn<Uint8List> previewPdf = Rxn<Uint8List>();
  final RxInt previewVersion = 0.obs;
  final RxBool buildingPreview = false.obs;
  final RxBool busy = false.obs;
  final RxList<String> problems = <String>[].obs;
  final RxInt labelsToPrint = 0.obs;
  final RxInt sheetsToPrint = 0.obs;

  final List<Worker> _workers = [];
  LabelFonts? _fonts;
  Timer? _previewTimer;
  int _previewNumber = 0;

  LabelDesign get design => designer.design.value;

  bool get usesExcel => design.usesExcelColumns;

  int get excelRowCount => designer.dataTable.value?.rows.length ?? 0;

  @override
  void onInit() {
    super.onInit();
    _resetRowChoices();
    labelCountWithoutExcel.value = design.sheet.labelsPerSheet;
    serialStarts.assignAll(_savedOrDesignSerialStarts());
    typedAnswers.assignAll(_lastTypedAnswers());
    _workers.add(
      everAll([
        rowChoice,
        rowsFrom,
        rowsTo,
        pickedRowNumbers,
        labelCountWithoutExcel,
        copiesPerRecord,
        startAtPosition,
        serialStarts,
        typedAnswers,
        offset,
        settings.lengthUnit,
      ], (_) => schedulePreview()),
    );
    _workers.add(
      ever(designer.dataTable, (_) {
        _resetRowChoices();
        schedulePreview();
      }),
    );
    _loadFontsThenPreview();
    refreshPrinters();
    designer.loadLinkedDataFile();
  }

  @override
  void onClose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    _previewTimer?.cancel();
    super.onClose();
  }

  int? savedSerialStart(String serialKey) {
    return designer.savedSerialStart(serialKey);
  }

  void changeSerialStart(String serialKey, int start) {
    serialStarts[serialKey] = start;
  }

  void changeTypedAnswer(String questionKey, String answer) {
    typedAnswers[questionKey] = answer;
  }

  void choosePickedRows(List<int> rowNumbers) {
    pickedRowNumbers.assignAll([...rowNumbers]..sort());
    rowChoice.value = RowChoice.picked;
  }

  Future<void> refreshPrinters() async {
    final found = await _availablePrinters();
    printers.assignAll(found);
    final lastName = settings.lastPrinterName();
    selectedPrinter.value =
        found.firstWhereOrNull((printer) => printer.name == lastName) ??
        found.firstWhereOrNull((printer) => printer.isDefault) ??
        found.firstOrNull;
    _loadOffsetOfSelectedPrinter();
  }

  void choosePrinter(Printer printer) {
    selectedPrinter.value = printer;
    settings.rememberLastPrinter(printer.name);
    _loadOffsetOfSelectedPrinter();
  }

  void changeOffset(PrinterOffset changed) {
    offset.value = changed;
    final printer = selectedPrinter.value;
    if (printer != null) settings.savePrinterOffset(printer.name, changed);
  }

  void schedulePreview({bool immediately = false}) {
    _previewTimer?.cancel();
    _previewTimer = Timer(
      immediately ? Duration.zero : const Duration(milliseconds: 350),
      _buildPreview,
    );
  }

  Future<PrintOutcome> printLabels() async {
    final request = _currentRequest();
    if (request == null) return const PrintOutcome.failed('Still loading.');
    busy.value = true;
    try {
      if (await designer.reloadDataFileIfChanged()) {
        return const PrintOutcome.failed(excelChangedMessage);
      }
      final blocking = await _problemsFor(request);
      if (blocking.isNotEmpty) return PrintOutcome.failed(blocking.first);
      final pdf = await buildLabelSheetsPdfInBackground(request);
      final printed = await _sendToPrinter(pdf);
      if (!printed) return const PrintOutcome.failed('Printing was cancelled.');
      await _rememberAfterPrinting(request);
      return PrintOutcome.succeeded(
        'Sent ${request.labelCount} labels on ${request.sheetCount} sheets '
        'to ${selectedPrinter.value?.name ?? 'the printer'}.',
      );
    } on Object catch (error) {
      return PrintOutcome.failed('Could not print: $error');
    } finally {
      busy.value = false;
    }
  }

  Future<PrintOutcome> saveAsPdf() async {
    final request = _currentRequest();
    if (request == null) return const PrintOutcome.failed('Still loading.');
    busy.value = true;
    try {
      if (await designer.reloadDataFileIfChanged()) {
        return const PrintOutcome.failed(excelChangedMessage);
      }
      final blocking = await _problemsFor(request);
      if (blocking.isNotEmpty) return PrintOutcome.failed(blocking.first);
      final pdf = await buildLabelSheetsPdfInBackground(request);
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Save the labels as a PDF',
        fileName: '${safeFileName(design.name)}.pdf',
        bytes: pdf,
      );
      if (savedUri == null) {
        return const PrintOutcome.failed('Saving was cancelled.');
      }
      await _rememberAfterPrinting(request);
      return PrintOutcome.succeeded(
        'Saved ${request.labelCount} labels on ${request.sheetCount} sheets '
        'as a PDF.',
      );
    } on Object catch (error) {
      return PrintOutcome.failed(
        'Could not save the PDF. If it is open in another program, close it '
        'and try again. ($error)',
      );
    } finally {
      busy.value = false;
    }
  }

  Future<PrintOutcome> printAlignmentTest() async {
    final fonts = _fonts;
    if (fonts == null) return const PrintOutcome.failed('Still loading.');
    busy.value = true;
    try {
      final pdf = await buildAlignmentTestPdf(
        sheet: design.sheet,
        offset: offset.value,
        regularFont: fonts.robotoFiles.regular,
      );
      final printed = await _sendToPrinter(pdf);
      if (!printed) return const PrintOutcome.failed('Printing was cancelled.');
      return const PrintOutcome.succeeded(
        'Test sheet sent. Hold it on a label sheet against the light.',
      );
    } on Object catch (error) {
      return PrintOutcome.failed('Could not print the test sheet: $error');
    } finally {
      busy.value = false;
    }
  }

  void _resetRowChoices() {
    final table = designer.dataTable.value;
    rowsFrom.value = table == null || table.rows.isEmpty
        ? 1
        : table.firstExcelRow;
    rowsTo.value = table == null || table.rows.isEmpty ? 1 : table.lastExcelRow;
    pickedRowNumbers.clear();
    if (rowChoice.value == RowChoice.picked) rowChoice.value = RowChoice.all;
  }

  Map<String, int> _savedOrDesignSerialStarts() {
    return {
      for (final source in design.serialNumberSources)
        source.key: savedSerialStart(source.key) ?? source.rule.start,
    };
  }

  bool isNewSerialInPrintedDesign(String serialKey) {
    return savedSerialStart(serialKey) == null &&
        settings.hasSavedSerialStarts(design.id);
  }

  Map<String, String> _lastTypedAnswers() {
    return {
      for (final question in design.printQuestions)
        question.key:
            settings.lastTypedAnswer(
              designId: design.id,
              questionKey: question.key,
            ) ??
            '',
    };
  }

  Future<List<Printer>> _availablePrinters() async {
    try {
      return await Printing.listPrinters();
    } on PlatformException {
      return const [];
    }
  }

  void _loadOffsetOfSelectedPrinter() {
    final printer = selectedPrinter.value;
    offset.value = printer == null
        ? PrinterOffset.none
        : settings.printerOffsetFor(printer.name);
  }

  Future<void> _loadFontsThenPreview() async {
    _fonts = LabelFonts({
      for (final font in LabelFont.values)
        BuiltInFont(font): await _builtInFilesOf(font),
      ...await _installedFontFilesUsedByDesign(),
    });
    schedulePreview(immediately: true);
  }

  Future<Map<TextFont, FontFiles>> _installedFontFilesUsedByDesign() async {
    final used = design.fontsUsed.whereType<InstalledFont>().toList();
    if (used.isEmpty) return const {};
    await installedFonts.lookAgain();
    final filesByFont = <TextFont, FontFiles>{};
    for (final font in used) {
      try {
        final files = await installedFonts.filesOf(font);
        if (files != null) filesByFont[font] = files;
      } on FileSystemException {
        continue;
      }
    }
    return filesByFont;
  }

  Future<FontFiles> _builtInFilesOf(LabelFont font) async {
    final regular = await rootBundle.load(font.regularAsset);
    final bold = await rootBundle.load(font.boldAsset);
    return FontFiles(
      regular: regular.buffer.asUint8List(),
      bold: bold.buffer.asUint8List(),
    );
  }

  LabelPrintRequest? _currentRequest() {
    final fonts = _fonts;
    if (fonts == null) return null;
    final chosen = _chosenRecords();
    return LabelPrintRequest(
      design: design,
      records: chosen.rows,
      recordNumbers: chosen.numbers,
      copiesPerRecord: copiesPerRecord.value,
      startAtPosition: startAtPosition.value,
      serialStarts: Map.of(serialStarts),
      typedAnswers: Map.of(typedAnswers),
      offset: offset.value,
      today: DateTime.now(),
      fonts: fonts.onlyFor(design.fontsUsed),
    );
  }

  _ChosenRecords _chosenRecords() {
    if (!usesExcel) {
      final count = math.max(0, labelCountWithoutExcel.value);
      return _ChosenRecords(
        rows: List.filled(count, const {}),
        numbers: [for (var number = 1; number <= count; number++) number],
      );
    }
    final table = designer.dataTable.value;
    if (table == null) return const _ChosenRecords(rows: [], numbers: []);
    final picked = pickedRowNumbers.toSet();
    final rows = <Map<String, String>>[];
    final numbers = <int>[];
    for (var index = 0; index < table.rows.length; index++) {
      final excelRow = table.excelRowNumbers[index];
      if (_isChosenRow(excelRow, picked)) {
        rows.add(table.rows[index]);
        numbers.add(excelRow);
      }
    }
    return _ChosenRecords(rows: rows, numbers: numbers);
  }

  bool _isChosenRow(int excelRow, Set<int> picked) {
    return switch (rowChoice.value) {
      RowChoice.all => true,
      RowChoice.range => excelRow >= rowsFrom.value && excelRow <= rowsTo.value,
      RowChoice.picked => picked.contains(excelRow),
    };
  }

  Future<List<String>> _problemsFor(LabelPrintRequest request) async {
    final rowProblems = _rowChoiceProblems();
    final otherProblems = await findPrintProblemsInBackground(
      request,
      availableColumns: designer.availableColumns,
      unit: settings.lengthUnit.value,
    );
    if (rowProblems.isEmpty) return otherProblems;
    return [
      ...rowProblems,
      ...otherProblems.where((problem) => problem != nothingToPrintProblem),
    ];
  }

  List<String> _rowChoiceProblems() {
    if (!usesExcel) return const [];
    if (designer.dataTable.value == null) {
      return const ['Choose the Excel file to print from.'];
    }
    return [
      if (rowChoice.value == RowChoice.range && rowsFrom.value > rowsTo.value)
        '"From Excel row" must not be after "To Excel row".',
      if (rowChoice.value == RowChoice.picked && pickedRowNumbers.isEmpty)
        'Pick at least one row to print.',
    ];
  }

  Future<void> _buildPreview() async {
    final request = _currentRequest();
    if (request == null) return;
    final previewNumber = ++_previewNumber;
    labelsToPrint.value = request.labelCount;
    sheetsToPrint.value = request.sheetCount;
    buildingPreview.value = true;
    try {
      final found = await _problemsFor(request);
      if (previewNumber != _previewNumber) return;
      problems.assignAll(found);
      if (request.labelCount == 0) {
        previewPdf.value = null;
        return;
      }
      final preview = request.limitedToSheets(previewSheetLimit);
      final pdf = await buildLabelSheetsPdfInBackground(preview);
      if (previewNumber != _previewNumber) return;
      previewPdf.value = pdf;
      previewVersion.value++;
    } on Object catch (error) {
      if (previewNumber == _previewNumber) {
        problems.assignAll(['The preview could not be made: $error']);
      }
    } finally {
      if (previewNumber == _previewNumber) buildingPreview.value = false;
    }
  }

  Future<bool> _sendToPrinter(Uint8List pdf) async {
    final printer = selectedPrinter.value;
    final format = pageFormatOf(design.sheet);
    if (printer == null) {
      return Printing.layoutPdf(
        onLayout: (_) async => pdf,
        name: design.name,
        format: format,
      );
    }
    return Printing.directPrintPdf(
      printer: printer,
      onLayout: (_) async => pdf,
      name: design.name,
      format: format,
    );
  }

  Future<void> _rememberAfterPrinting(LabelPrintRequest request) async {
    final nextStarts = {
      for (final source in design.serialNumberSources)
        source.key: serialStartAfterPrinting(
          source.rule,
          request.serialStarts[source.key] ?? source.rule.start,
          request.records.length,
        ),
    };
    await settings.saveNextSerialStarts(
      designId: design.id,
      nextStartBySerialKey: nextStarts,
    );
    await settings.saveTypedAnswers(
      designId: design.id,
      answerByQuestionKey: request.typedAnswers,
    );
    serialStarts.assignAll(nextStarts);
  }
}
