import 'dart:io';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../core/settings/app_settings_store.dart';
import '../../../core/units.dart';
import '../../design/data/design_file_store.dart';
import '../../design/data/models/label_design.dart';
import '../../design/data/models/label_item.dart';
import '../../spreadsheet/data/models/spreadsheet_table.dart';
import '../../spreadsheet/data/spreadsheet_reader.dart';
import 'new_label_items.dart';

const int _maxUndoSteps = 200;

class DesignerController extends GetxController {
  DesignerController({
    required LabelDesign initialDesign,
    String? initialFilePath,
    required this.designFiles,
    required this.spreadsheets,
    required this.settings,
  }) : design = initialDesign.obs,
       filePath = RxnString(initialFilePath);

  final DesignFileStore designFiles;
  final SpreadsheetReader spreadsheets;
  final AppSettingsStore settings;

  final Rx<LabelDesign> design;
  final RxnString filePath;
  final RxnString selectedItemId = RxnString();
  final RxBool hasUnsavedChanges = false.obs;
  final RxBool canUndo = false.obs;
  final RxBool canRedo = false.obs;
  final Rxn<SpreadsheetTable> dataTable = Rxn<SpreadsheetTable>();
  final RxnString dataFileProblem = RxnString();
  final RxBool snapToGrid = true.obs;

  final List<LabelDesign> _undoHistory = [];
  final List<LabelDesign> _redoHistory = [];
  String? _lastChangeKey;
  int _gestureCount = 0;
  DateTime? _dataFileModifiedAt;

  LabelItem? get selectedItem {
    final id = selectedItemId.value;
    return id == null ? null : design.value.itemById(id);
  }

  Map<String, String> get previewRow {
    final rows = dataTable.value?.rows;
    return rows == null || rows.isEmpty ? const {} : rows.first;
  }

  List<String> get availableColumns => dataTable.value?.headers ?? const [];

  void selectItem(String? itemId) => selectedItemId.value = itemId;

  void addTextItem() => _addItem(newTextItem(design.value));

  void addBarcodeItem() => _addItem(newBarcodeItem(design.value));

  void addQrCodeItem() => _addItem(newQrCodeItem(design.value));

  void addShapeItem(ShapeKind shape) {
    _addItem(newShapeItem(design.value, shape));
  }

  void addPictureItem(Uint8List imageBytes, double widthOverHeight) {
    _addItem(newPictureItem(design.value, imageBytes, widthOverHeight));
  }

  void replaceItem(LabelItem item, {String? changeKey}) {
    final items = [
      for (final existing in design.value.items)
        existing.id == item.id ? item : existing,
    ];
    _changeDesign(design.value.copyWith(items: items), changeKey: changeKey);
  }

  void deleteSelectedItem() {
    final id = selectedItemId.value;
    if (id == null) return;
    final items = design.value.items.where((item) => item.id != id).toList();
    _changeDesign(design.value.copyWith(items: items));
    selectItem(null);
  }

  void duplicateSelectedItem() {
    final item = selectedItem;
    if (item == null) return;
    _addItem(duplicateOf(item, design.value));
  }

  void bringSelectedItemToFront() {
    final item = selectedItem;
    if (item == null) return;
    final others = design.value.items.where((other) => other.id != item.id);
    _changeDesign(design.value.copyWith(items: [...others, item]));
  }

  void sendSelectedItemToBack() {
    final item = selectedItem;
    if (item == null) return;
    final others = design.value.items.where((other) => other.id != item.id);
    _changeDesign(design.value.copyWith(items: [item, ...others]));
  }

  void nudgeSelectedItem(double rightMm, double downMm) {
    final item = selectedItem;
    if (item == null) return;
    final frame = item.frame;
    final moved = frame.copyWith(
      x: snappedMm(frame.x + rightMm),
      y: snappedMm(frame.y + downMm),
    );
    replaceItem(
      item.copyWithCommon(frame: moved),
      changeKey: 'nudge:${item.id}',
    );
  }

  int startItemGesture(String itemId) {
    selectItem(itemId);
    _gestureCount++;
    return _gestureCount;
  }

  void moveItemDuringGesture(String itemId, ItemFrame frame, int gestureId) {
    final item = design.value.itemById(itemId);
    if (item == null) return;
    replaceItem(
      item.copyWithCommon(frame: frame),
      changeKey: 'gesture:$gestureId',
    );
  }

  double snappedMm(double mm) {
    if (!snapToGrid.value) return roundToTenthMm(mm);
    final step = settings.lengthUnit.value.snapStepMm;
    return (mm / step).roundToDouble() * step;
  }

  int? savedSerialStart(String serialKey) {
    final designId = design.value.id;
    final saved = settings.nextSerialStart(
      designId: designId,
      serialKey: serialKey,
    );
    if (saved != null || !serialKey.contains('/')) return saved;
    final itemId = serialKey.substring(0, serialKey.indexOf('/'));
    return settings.nextSerialStart(designId: designId, serialKey: itemId);
  }

  Map<String, int> savedSerialStarts() {
    return {
      for (final source in design.value.serialNumberSources)
        source.key: ?savedSerialStart(source.key),
    };
  }

  Map<String, String> lastTypedAnswers() {
    final designId = design.value.id;
    final answers = <String, String>{};
    for (final question in design.value.printQuestions) {
      final answer = settings.lastTypedAnswer(
        designId: designId,
        questionKey: question.key,
      );
      if (answer != null && answer.trim().isNotEmpty) {
        answers[question.key] = answer;
      }
    }
    return answers;
  }

  void updateSheet(SheetLayout sheet) {
    _changeDesign(design.value.copyWith(sheet: sheet));
  }

  void linkDataFile(DataFileLink link, SpreadsheetTable table) {
    dataTable.value = table;
    dataFileProblem.value = null;
    _changeDesign(design.value.copyWith(dataFile: link));
    _modifiedTimeOf(link.path).then((time) => _dataFileModifiedAt = time);
  }

  void unlinkDataFile() {
    dataTable.value = null;
    dataFileProblem.value = null;
    _changeDesign(design.value.copyWith(removeDataFile: true));
  }

  Future<bool> reloadDataFileIfChanged() async {
    final link = design.value.dataFile;
    if (link == null) return false;
    final modifiedAt = await _modifiedTimeOf(link.path);
    if (modifiedAt == null || modifiedAt == _dataFileModifiedAt) return false;
    await loadLinkedDataFile();
    return true;
  }

  Future<DateTime?> _modifiedTimeOf(String path) async {
    try {
      return await File(path).lastModified();
    } on FileSystemException {
      return null;
    }
  }

  Future<void> loadLinkedDataFile() async {
    final link = design.value.dataFile;
    if (link == null) return;
    try {
      _dataFileModifiedAt = await _modifiedTimeOf(link.path);
      dataTable.value = await spreadsheets.readTable(link.path, link.sheetName);
      dataFileProblem.value = null;
    } on SpreadsheetReadException catch (error) {
      dataTable.value = null;
      dataFileProblem.value = error.message;
    } on Object catch (error) {
      dataTable.value = null;
      dataFileProblem.value = 'The file could not be read ($error).';
    }
  }

  void undo() {
    if (_undoHistory.isEmpty) return;
    final before = design.value;
    _redoHistory.add(before);
    design.value = _undoHistory.removeLast();
    _afterHistoryJump(before);
  }

  void redo() {
    if (_redoHistory.isEmpty) return;
    final before = design.value;
    _undoHistory.add(before);
    design.value = _redoHistory.removeLast();
    _afterHistoryJump(before);
  }

  Future<bool> save() async {
    final path = filePath.value;
    if (path == null) return saveAs();
    await designFiles.writeDesign(path, design.value);
    await _markSavedAt(path);
    return true;
  }

  Future<bool> saveAs() async {
    final path = await designFiles.saveDesignWithDialog(design.value);
    if (path == null) return false;
    final renamed = design.value.copyWith(
      name: p.basenameWithoutExtension(path),
    );
    await designFiles.writeDesign(path, renamed);
    design.value = renamed;
    await _markSavedAt(path);
    return true;
  }

  void _addItem(LabelItem item) {
    _changeDesign(design.value.copyWith(items: [...design.value.items, item]));
    selectItem(item.id);
  }

  void _changeDesign(LabelDesign next, {String? changeKey}) {
    final continuesLastChange =
        changeKey != null && changeKey == _lastChangeKey;
    if (!continuesLastChange) {
      _undoHistory.add(design.value);
      if (_undoHistory.length > _maxUndoSteps) _undoHistory.removeAt(0);
    }
    _redoHistory.clear();
    _lastChangeKey = changeKey;
    design.value = next;
    hasUnsavedChanges.value = true;
    _refreshUndoFlags();
  }

  void _afterHistoryJump(LabelDesign before) {
    _lastChangeKey = null;
    hasUnsavedChanges.value = true;
    if (selectedItem == null) selectItem(null);
    _refreshUndoFlags();
    if (_linksDifferentData(before.dataFile, design.value.dataFile)) {
      _reloadDataAfterLinkChange();
    }
  }

  bool _linksDifferentData(DataFileLink? before, DataFileLink? after) {
    return before?.path != after?.path || before?.sheetName != after?.sheetName;
  }

  void _reloadDataAfterLinkChange() {
    if (design.value.dataFile == null) {
      dataTable.value = null;
      dataFileProblem.value = null;
      return;
    }
    loadLinkedDataFile();
  }

  void _refreshUndoFlags() {
    canUndo.value = _undoHistory.isNotEmpty;
    canRedo.value = _redoHistory.isNotEmpty;
  }

  Future<void> _markSavedAt(String path) async {
    filePath.value = path;
    hasUnsavedChanges.value = false;
    await settings.rememberRecentDesign(path);
  }
}
