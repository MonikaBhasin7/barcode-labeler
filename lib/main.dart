import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/barcode_labeler_app.dart';
import 'core/fonts/installed_fonts.dart';
import 'core/settings/app_settings_store.dart';
import 'features/design/data/design_file_store.dart';
import 'features/design/data/models/label_font.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_fontLicenses);
  final preferences = await SharedPreferences.getInstance();
  Get.put(AppSettingsStore(preferences));
  Get.put(InstalledFonts()).lookAgain();
  runApp(BarcodeLabelerApp(designPathToOpen: _designPathIn(arguments)));
}

String? _designPathIn(List<String> arguments) {
  for (final argument in arguments) {
    if (argument.toLowerCase().endsWith('.$designFileExtension')) {
      return argument;
    }
  }
  return null;
}

Stream<LicenseEntry> _fontLicenses() async* {
  final text = await rootBundle.loadString('assets/fonts/FONT_LICENSES.txt');
  yield LicenseEntryWithLineBreaks([
    for (final font in LabelFont.values) font.familyName,
  ], text);
}
