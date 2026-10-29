import 'dart:io';
import 'dart:typed_data';

import 'package:barcode_labeler/core/fonts/installed_font_files.dart';
import 'package:barcode_labeler/features/design/data/models/label_font.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';

Uint8List bundled(String fileName) {
  return File('assets/fonts/$fileName').readAsBytesSync();
}

Uint8List collectionOf(List<Uint8List> fonts) {
  final directories = [for (final font in fonts) ByteData.sublistView(font)];
  final tableCounts = [
    for (final directory in directories) directory.getUint16(4),
  ];
  final headerLength = 12 + fonts.length * 4;
  var nextOffset = headerLength;
  final fontStarts = <int>[];
  for (final count in tableCounts) {
    fontStarts.add(nextOffset);
    nextOffset += 12 + count * 16;
  }
  final tableStarts = <List<int>>[];
  for (var font = 0; font < fonts.length; font++) {
    final starts = <int>[];
    for (var table = 0; table < tableCounts[font]; table++) {
      starts.add(nextOffset);
      final length = directories[font].getUint32(12 + table * 16 + 12);
      nextOffset += (length + 3) & ~3;
    }
    tableStarts.add(starts);
  }
  final collection = Uint8List(nextOffset);
  final out = ByteData.sublistView(collection);
  out.setUint32(0, 0x74746366);
  out.setUint32(4, 0x00010000);
  out.setUint32(8, fonts.length);
  for (var font = 0; font < fonts.length; font++) {
    out.setUint32(12 + font * 4, fontStarts[font]);
    final start = fontStarts[font];
    collection.setRange(start, start + 12, fonts[font]);
    for (var table = 0; table < tableCounts[font]; table++) {
      final record = 12 + table * 16;
      final offset = directories[font].getUint32(record + 8);
      final length = directories[font].getUint32(record + 12);
      collection.setRange(
        start + record,
        start + record + 8,
        fonts[font],
        record,
      );
      out.setUint32(start + record + 8, tableStarts[font][table]);
      out.setUint32(start + record + 12, length);
      collection.setRange(
        tableStarts[font][table],
        tableStarts[font][table] + length,
        fonts[font],
        offset,
      );
    }
  }
  return collection;
}

void main() {
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('fonts_test'));

  tearDown(() => folder.deleteSync(recursive: true));

  void putFont(String fileName, Uint8List bytes) {
    File(p.join(folder.path, fileName)).writeAsBytesSync(bytes);
  }

  test('normal and bold files of one font become one family', () {
    putFont('Lato-Regular.ttf', bundled('Lato-Regular.ttf'));
    putFont('Lato-Bold.ttf', bundled('Lato-Bold.ttf'));
    putFont('Tinos-Regular.ttf', bundled('Tinos-Regular.ttf'));

    final families = findInstalledFontFamilies([folder.path]);

    expect(families.map((family) => family.name), ['Lato', 'Tinos']);
    expect(families.first.canPrint, isTrue);
    expect(p.basename(families.first.regular.path), 'Lato-Regular.ttf');
    expect(p.basename(families.first.bold!.path), 'Lato-Bold.ttf');
    expect(families.last.hasBold, isFalse);
  });

  test('a font with the other kind of outlines cannot be printed', () {
    final copy = Uint8List.fromList(bundled('Rubik-Regular.ttf'));
    ByteData.sublistView(copy).setUint32(0, 0x4F54544F);
    putFont('Rubik-Regular.otf', copy);

    final family = findInstalledFontFamilies([folder.path]).single;

    expect(family.name, 'Rubik');
    expect(family.canPrint, isFalse);
  });

  test('broken files and other files are skipped', () {
    putFont('broken.ttf', Uint8List.fromList([1, 2, 3, 4, 5, 6, 7]));
    putFont('notes.txt', Uint8List.fromList([65, 66, 67]));

    expect(findInstalledFontFamilies([folder.path]), isEmpty);
  });

  test('a missing folder finds nothing', () {
    expect(findInstalledFontFamilies([p.join(folder.path, 'nope')]), isEmpty);
  });

  test('fonts inside a collection file are found and can print', () async {
    final regular = bundled('Lato-Regular.ttf');
    putFont('Lato.ttc', collectionOf([regular, bundled('Lato-Bold.ttf')]));

    final family = findInstalledFontFamilies([folder.path]).single;
    final extracted = await readFontFaceBytes(family.regular);
    final fromCollection = PdfTtfFont(
      PdfDocument(),
      ByteData.sublistView(extracted),
    );
    final original = PdfTtfFont(PdfDocument(), ByteData.sublistView(regular));

    expect(family.name, 'Lato');
    expect(family.canPrint, isTrue);
    expect(family.regular.collectionIndex, 0);
    expect(family.bold!.collectionIndex, 1);
    expect(
      fromCollection.stringMetrics('Shirt 42').advanceWidth,
      original.stringMetrics('Shirt 42').advanceWidth,
    );
  });

  test('every font the app ships with is also understood as a file', () {
    for (final font in LabelFont.values) {
      final faces = readFontFaces(font.regularAsset);

      expect(faces.single.canPrint, isTrue, reason: font.label);
      expect(faces.single.isBold, isFalse, reason: font.label);
      expect(readFontFaces(font.boldAsset).single.isBold, isTrue);
    }
  });
}
