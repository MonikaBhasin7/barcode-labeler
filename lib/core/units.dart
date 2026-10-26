const double pointsPerMm = 72 / 25.4;
const double mmPerPoint = 25.4 / 72;

double roundToTenthMm(double mm) => (mm * 10).roundToDouble() / 10;

enum LengthUnit {
  mm('mm', 1, 1, 1, '1 mm'),
  cm('cm', 10, 2, 1, '1 mm'),
  inch('in', 25.4, 2, 1.27, '0.05 in');

  const LengthUnit(
    this.label,
    this.mmPerUnit,
    this.decimals,
    this.snapStepMm,
    this.snapStepLabel,
  );

  final String label;
  final double mmPerUnit;
  final int decimals;
  final double snapStepMm;
  final String snapStepLabel;

  double fromMm(double mm) => mm / mmPerUnit;

  double toMm(double value) => value * mmPerUnit;

  String format(double mm) {
    final fixed = fromMm(mm).toStringAsFixed(decimals);
    if (!fixed.contains('.')) return fixed;
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String formatWithLabel(double mm) => '${format(mm)} $label';
}
