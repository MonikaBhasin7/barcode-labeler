import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/printing/data/models/printer_offset.dart';
import '../json_reading.dart';
import '../units.dart';

class AppSettingsStore {
  AppSettingsStore(this._preferences)
    : lengthUnit = readEnum(
        LengthUnit.values,
        _preferences.getString(_lengthUnitKey),
        LengthUnit.mm,
      ).obs;

  static const int _maxRecentDesigns = 10;
  static const String _recentDesignsKey = 'recent_design_paths';
  static const String _lastPrinterKey = 'last_printer_name';
  static const String _printerOffsetsKey = 'printer_offsets';
  static const String _nextSerialStartsKey = 'next_serial_starts';
  static const String _typedAnswersKey = 'typed_answers';
  static const String _lengthUnitKey = 'length_unit';

  final SharedPreferences _preferences;
  final Rx<LengthUnit> lengthUnit;

  Future<void> chooseLengthUnit(LengthUnit unit) async {
    lengthUnit.value = unit;
    await _preferences.setString(_lengthUnitKey, unit.name);
  }

  List<String> recentDesignPaths() {
    return _preferences.getStringList(_recentDesignsKey) ?? const [];
  }

  Future<void> rememberRecentDesign(String path) async {
    final paths = [
      path,
      ...recentDesignPaths().where((existing) => existing != path),
    ].take(_maxRecentDesigns).toList();
    await _preferences.setStringList(_recentDesignsKey, paths);
  }

  Future<void> forgetRecentDesign(String path) async {
    final paths = recentDesignPaths().where((existing) => existing != path);
    await _preferences.setStringList(_recentDesignsKey, paths.toList());
  }

  String? lastPrinterName() => _preferences.getString(_lastPrinterKey);

  Future<void> rememberLastPrinter(String printerName) async {
    await _preferences.setString(_lastPrinterKey, printerName);
  }

  PrinterOffset printerOffsetFor(String printerName) {
    final saved = _readJsonMap(_printerOffsetsKey)[printerName];
    return saved is Map<String, dynamic>
        ? PrinterOffset.fromJson(saved)
        : PrinterOffset.none;
  }

  Future<void> savePrinterOffset(
    String printerName,
    PrinterOffset offset,
  ) async {
    final offsets = _readJsonMap(_printerOffsetsKey);
    offsets[printerName] = offset.toJson();
    await _preferences.setString(_printerOffsetsKey, jsonEncode(offsets));
  }

  int? nextSerialStart({required String designId, required String serialKey}) {
    final saved = _readJsonMap(_nextSerialStartsKey)['$designId/$serialKey'];
    return saved is int ? saved : null;
  }

  Future<void> saveNextSerialStarts({
    required String designId,
    required Map<String, int> nextStartBySerialKey,
  }) async {
    final starts = _readJsonMap(_nextSerialStartsKey);
    for (final entry in nextStartBySerialKey.entries) {
      starts['$designId/${entry.key}'] = entry.value;
    }
    await _preferences.setString(_nextSerialStartsKey, jsonEncode(starts));
  }

  bool hasSavedSerialStarts(String designId) {
    return _readJsonMap(
      _nextSerialStartsKey,
    ).keys.any((key) => key.startsWith('$designId/'));
  }

  String? lastTypedAnswer({
    required String designId,
    required String questionKey,
  }) {
    final saved = _readJsonMap(_typedAnswersKey)['$designId/$questionKey'];
    return saved is String ? saved : null;
  }

  Future<void> saveTypedAnswers({
    required String designId,
    required Map<String, String> answerByQuestionKey,
  }) async {
    final answers = _readJsonMap(_typedAnswersKey);
    for (final entry in answerByQuestionKey.entries) {
      answers['$designId/${entry.key}'] = entry.value;
    }
    await _preferences.setString(_typedAnswersKey, jsonEncode(answers));
  }

  Map<String, dynamic> _readJsonMap(String key) {
    final text = _preferences.getString(key);
    if (text == null) return {};
    final decoded = jsonDecode(text);
    return decoded is Map<String, dynamic> ? decoded : {};
  }
}
