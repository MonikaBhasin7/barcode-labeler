import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/barcode_labeler_app.dart';
import 'core/settings/app_settings_store.dart';
import 'features/design/data/design_file_store.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_robotoFontLicense);
  final preferences = await SharedPreferences.getInstance();
  Get.put(AppSettingsStore(preferences));
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

Stream<LicenseEntry> _robotoFontLicense() async* {
  yield const LicenseEntryWithLineBreaks(
    ['Roboto font'],
    'Copyright 2011 Google Inc. All Rights Reserved.\n\n'
    'Licensed under the Apache License, Version 2.0 (the "License"); you may '
    'not use this file except in compliance with the License. You may obtain '
    'a copy of the License at http://www.apache.org/licenses/LICENSE-2.0\n\n'
    'Unless required by applicable law or agreed to in writing, software '
    'distributed under the License is distributed on an "AS IS" BASIS, '
    'WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. '
    'See the License for the specific language governing permissions and '
    'limitations under the License.',
  );
}
