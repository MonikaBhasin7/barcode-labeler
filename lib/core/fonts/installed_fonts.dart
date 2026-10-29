import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../features/design/data/models/label_font.dart';
import '../../features/printing/application/label_print_request.dart';
import 'installed_font_files.dart';

class InstalledFonts {
  InstalledFonts({List<String>? folders})
    : _folders = folders ?? installedFontFolders();

  final List<String> _folders;
  final RxList<InstalledFontFamily> families = <InstalledFontFamily>[].obs;
  final RxBool lookingForFonts = false.obs;
  final RxnString searchProblem = RxnString();
  final Set<String> _familiesShownOnScreen = {};
  Future<void>? _searchInProgress;

  Future<void> lookAgain() {
    return _searchInProgress ??= _searchFolders().whenComplete(
      () => _searchInProgress = null,
    );
  }

  InstalledFontFamily? familyOf(InstalledFont font) {
    return families.firstWhereOrNull(
      (family) => family.name == font.familyName,
    );
  }

  bool hasBold(TextFont font) {
    return switch (font) {
      BuiltInFont() => true,
      final InstalledFont installed => familyOf(installed)?.hasBold ?? false,
    };
  }

  String? problemWith(InstalledFont font) {
    final family = familyOf(font);
    if (family == null) return lookingForFonts.value ? null : 'Not on this PC';
    return family.canPrint ? null : 'This font cannot be printed';
  }

  Future<FontFiles?> filesOf(InstalledFont font) async {
    final family = familyOf(font);
    if (family == null || !family.canPrint) return null;
    final regular = await readFontFaceBytes(family.regular);
    final bold = family.bold;
    return FontFiles(
      regular: regular,
      bold: bold == null ? regular : await readFontFaceBytes(bold),
    );
  }

  Future<void> showOnScreen(Iterable<TextFont> fonts) async {
    for (final font in fonts.whereType<InstalledFont>()) {
      if (!_familiesShownOnScreen.add(font.familyName)) continue;
      try {
        final files = await filesOf(font);
        if (files == null) {
          _familiesShownOnScreen.remove(font.familyName);
          continue;
        }
        await _loadOntoScreen(font, files);
      } on Object {
        _familiesShownOnScreen.remove(font.familyName);
      }
    }
  }

  Future<void> _loadOntoScreen(InstalledFont font, FontFiles files) async {
    final loader = FontLoader(font.screenFamily)
      ..addFont(Future.value(ByteData.sublistView(files.regular)));
    if (!identical(files.bold, files.regular)) {
      loader.addFont(Future.value(ByteData.sublistView(files.bold)));
    }
    await loader.load();
  }

  Future<void> _searchFolders() async {
    if (_folders.isEmpty) {
      families.clear();
      return;
    }
    lookingForFonts.value = true;
    try {
      final found = await findInstalledFontFamiliesInBackground(_folders);
      families.assignAll(
        found.where((family) => !isBuiltInFontName(family.name)),
      );
      searchProblem.value = null;
    } on Object catch (error) {
      searchProblem.value = 'The fonts on this PC could not be read ($error).';
    } finally {
      lookingForFonts.value = false;
    }
  }
}
