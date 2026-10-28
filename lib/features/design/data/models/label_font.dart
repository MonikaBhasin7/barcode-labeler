enum LabelFont {
  roboto('Roboto', 'Roboto'),
  robotoCondensed('Roboto Condensed (narrow)', 'RobotoCondensed'),
  robotoMono('Roboto Mono (same width letters)', 'RobotoMono'),
  lato('Lato', 'Lato'),
  montserrat('Montserrat (wide)', 'Montserrat'),
  libreFranklin('Libre Franklin', 'LibreFranklin'),
  rubik('Rubik (rounded)', 'Rubik'),
  workSans('Work Sans', 'WorkSans');

  const LabelFont(this.label, this.familyName);

  final String label;
  final String familyName;

  String get regularAsset => 'assets/fonts/$familyName-Regular.ttf';

  String get boldAsset => 'assets/fonts/$familyName-Bold.ttf';
}
