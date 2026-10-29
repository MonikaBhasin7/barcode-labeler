import '../../../../core/json_reading.dart';

enum LabelFont {
  roboto('Roboto', 'Roboto'),
  robotoCondensed('Roboto Condensed (narrow)', 'RobotoCondensed'),
  robotoMono('Roboto Mono (same width letters)', 'RobotoMono'),
  lato('Lato', 'Lato'),
  montserrat('Montserrat (wide)', 'Montserrat'),
  libreFranklin('Libre Franklin', 'LibreFranklin'),
  rubik('Rubik (rounded)', 'Rubik'),
  workSans('Work Sans', 'WorkSans'),
  tinos('Tinos (like Times New Roman)', 'Tinos');

  const LabelFont(this.label, this.familyName);

  final String label;
  final String familyName;

  String get regularAsset => 'assets/fonts/$familyName-Regular.ttf';

  String get boldAsset => 'assets/fonts/$familyName-Bold.ttf';
}

sealed class TextFont {
  const TextFont();

  factory TextFont.fromJson(Map<String, dynamic> json) {
    final installedFamily = readString(json, 'installedFont', '');
    if (installedFamily.isNotEmpty) return InstalledFont(installedFamily);
    return BuiltInFont(
      readEnum(LabelFont.values, json['font'], LabelFont.roboto),
    );
  }

  String get name;

  String get screenFamily;

  Map<String, dynamic> toJson();
}

final class BuiltInFont extends TextFont {
  const BuiltInFont(this.font);

  final LabelFont font;

  @override
  String get name => font.label;

  @override
  String get screenFamily => font.familyName;

  @override
  Map<String, dynamic> toJson() => {'font': font.name};

  @override
  bool operator ==(Object other) => other is BuiltInFont && other.font == font;

  @override
  int get hashCode => font.hashCode;
}

final class InstalledFont extends TextFont {
  const InstalledFont(this.familyName);

  final String familyName;

  @override
  String get name => familyName;

  @override
  String get screenFamily => 'Installed font $familyName';

  @override
  Map<String, dynamic> toJson() => {'installedFont': familyName};

  @override
  bool operator ==(Object other) {
    return other is InstalledFont && other.familyName == familyName;
  }

  @override
  int get hashCode => familyName.hashCode;
}

const TextFont robotoFont = BuiltInFont(LabelFont.roboto);

bool isBuiltInFontName(String familyName) {
  final squashed = familyName.replaceAll(' ', '').toLowerCase();
  return LabelFont.values.any(
    (font) => font.familyName.toLowerCase() == squashed,
  );
}
