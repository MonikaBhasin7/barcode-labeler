import 'package:barcode_labeler/core/file_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('replaces letters Windows does not allow in file names', () {
    expect(safeFileName('Box 1/2: big?'), 'Box 1-2- big-');
  });

  test('never gives an empty name', () {
    expect(safeFileName('  ...  '), 'Untitled');
  });
}
