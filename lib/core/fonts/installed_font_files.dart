import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

const Set<String> _fontFileExtensions = {'.ttf', '.otf', '.ttc', '.otc'};
const int _trueTypeOutlines = 0x00010000;
const int _appleTrueTypeOutlines = 0x74727565;
const int _fontCollection = 0x74746366;
const Set<String> _tablesNeededToPrint = {
  'head',
  'hhea',
  'hmtx',
  'maxp',
  'cmap',
  'name',
  'loca',
  'glyf',
};
const int _unicodePlatform = 0;
const int _macPlatform = 1;
const int _windowsPlatform = 3;
const int _englishUnitedStates = 0x409;
const int _familyNameId = 1;
const int _boldStyleBit = 0x20;
const int _italicStyleBit = 0x01;
const int _macBoldBit = 0x01;
const int _macItalicBit = 0x02;

class InstalledFontFamily {
  const InstalledFontFamily({
    required this.name,
    required this.regular,
    required this.bold,
  });

  final String name;
  final InstalledFontFace regular;
  final InstalledFontFace? bold;

  bool get canPrint => regular.canPrint;

  bool get hasBold => bold != null;
}

class InstalledFontFace {
  const InstalledFontFace({
    required this.path,
    required this.collectionIndex,
    required this.familyName,
    required this.isBold,
    required this.isItalic,
    required this.canPrint,
  });

  final String path;
  final int? collectionIndex;
  final String familyName;
  final bool isBold;
  final bool isItalic;
  final bool canPrint;
}

typedef _TableSpot = ({int offset, int length});

typedef _FaceStyle = ({bool isBold, bool isItalic});

List<String> installedFontFolders() {
  if (Platform.isWindows) {
    final windows = Platform.environment['WINDIR'] ?? r'C:\Windows';
    final localAppData = Platform.environment['LOCALAPPDATA'];
    return [
      p.join(windows, 'Fonts'),
      if (localAppData != null)
        p.join(localAppData, 'Microsoft', 'Windows', 'Fonts'),
    ];
  }
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    return [
      '/System/Library/Fonts',
      '/Library/Fonts',
      if (home != null) p.join(home, 'Library', 'Fonts'),
    ];
  }
  return const [];
}

Future<List<InstalledFontFamily>> findInstalledFontFamiliesInBackground(
  List<String> folders,
) {
  return Isolate.run(() => findInstalledFontFamilies(folders));
}

List<InstalledFontFamily> findInstalledFontFamilies(List<String> folders) {
  return familiesOf([
    for (final path in _fontFilePathsIn(folders)) ...readFontFaces(path),
  ]);
}

List<InstalledFontFamily> familiesOf(List<InstalledFontFace> faces) {
  final facesByFamily = <String, List<InstalledFontFace>>{};
  for (final face in faces) {
    (facesByFamily[face.familyName] ??= []).add(face);
  }
  return [
    for (final entry in facesByFamily.entries)
      _familyFrom(entry.key, entry.value),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

Future<Uint8List> readFontFaceBytes(InstalledFontFace face) async {
  final bytes = await File(face.path).readAsBytes();
  final index = face.collectionIndex;
  return index == null ? bytes : singleFontFromCollection(bytes, index);
}

Uint8List singleFontFromCollection(Uint8List collection, int index) {
  final source = ByteData.sublistView(collection);
  final start = source.getUint32(12 + index * 4);
  final tableCount = source.getUint16(start + 4);
  final directoryLength = 12 + tableCount * 16;
  var totalLength = directoryLength;
  for (var table = 0; table < tableCount; table++) {
    totalLength += _paddedToFour(source.getUint32(start + 24 + table * 16));
  }
  final single = Uint8List(totalLength);
  final target = ByteData.sublistView(single);
  single.setRange(0, 12, collection, start);
  var nextTableOffset = directoryLength;
  for (var table = 0; table < tableCount; table++) {
    final record = 12 + table * 16;
    final offset = source.getUint32(start + record + 8);
    final length = source.getUint32(start + record + 12);
    single.setRange(record, record + 8, collection, start + record);
    target.setUint32(record + 8, nextTableOffset);
    target.setUint32(record + 12, length);
    single.setRange(
      nextTableOffset,
      nextTableOffset + length,
      collection,
      offset,
    );
    nextTableOffset += _paddedToFour(length);
  }
  return single;
}

int _paddedToFour(int length) => (length + 3) & ~3;

List<InstalledFontFace> readFontFaces(String path) {
  try {
    final file = File(path).openSync();
    try {
      return _facesInOpenFile(file, path);
    } finally {
      file.closeSync();
    }
  } on Object {
    return const [];
  }
}

List<String> _fontFilePathsIn(List<String> folders) {
  final paths = <String>[];
  for (final folder in folders) {
    final directory = Directory(folder);
    if (!directory.existsSync()) continue;
    try {
      for (final entity in directory.listSync(recursive: true)) {
        final extension = p.extension(entity.path).toLowerCase();
        if (entity is File && _fontFileExtensions.contains(extension)) {
          paths.add(entity.path);
        }
      }
    } on FileSystemException {
      continue;
    }
  }
  return paths;
}

InstalledFontFamily _familyFrom(String name, List<InstalledFontFace> faces) {
  final regular =
      _bestFace(faces, isBold: false) ??
      _bestFace(faces, isBold: true) ??
      faces.first;
  final bold = _bestFace(faces, isBold: true);
  return InstalledFontFamily(
    name: name,
    regular: regular,
    bold: bold != null && bold != regular && bold.canPrint ? bold : null,
  );
}

InstalledFontFace? _bestFace(
  List<InstalledFontFace> faces, {
  required bool isBold,
}) {
  final upright = faces.where(
    (face) => face.isBold == isBold && !face.isItalic,
  );
  for (final face in upright) {
    if (face.canPrint) return face;
  }
  return upright.firstOrNull;
}

List<InstalledFontFace> _facesInOpenFile(RandomAccessFile file, String path) {
  if (_bytesAt(file, 0, 4).getUint32(0) != _fontCollection) {
    return [?_faceAt(file, path, 0, collectionIndex: null)];
  }
  final count = _bytesAt(file, 8, 4).getUint32(0);
  final offsets = _bytesAt(file, 12, count * 4);
  return [
    for (var index = 0; index < count; index++)
      ?_faceAt(
        file,
        path,
        offsets.getUint32(index * 4),
        collectionIndex: index,
      ),
  ];
}

InstalledFontFace? _faceAt(
  RandomAccessFile file,
  String path,
  int start, {
  required int? collectionIndex,
}) {
  final header = _bytesAt(file, start, 12);
  final outlines = header.getUint32(0);
  final tables = _tableSpots(file, start + 12, header.getUint16(4));
  final nameTable = tables['name'];
  if (nameTable == null) return null;
  final familyName = _familyNameIn(
    _bytesAt(file, nameTable.offset, nameTable.length),
  );
  if (familyName == null || familyName.isEmpty || familyName.startsWith('.')) {
    return null;
  }
  final style = _styleOf(file, tables);
  final hasTrueTypeOutlines =
      outlines == _trueTypeOutlines || outlines == _appleTrueTypeOutlines;
  return InstalledFontFace(
    path: path,
    collectionIndex: collectionIndex,
    familyName: familyName,
    isBold: style.isBold,
    isItalic: style.isItalic,
    canPrint:
        hasTrueTypeOutlines &&
        tables.keys.toSet().containsAll(_tablesNeededToPrint),
  );
}

Map<String, _TableSpot> _tableSpots(
  RandomAccessFile file,
  int start,
  int count,
) {
  final records = _bytesAt(file, start, count * 16);
  return {
    for (var index = 0; index < count; index++)
      latin1.decode(
        Uint8List.sublistView(records, index * 16, index * 16 + 4),
      ): (
        offset: records.getUint32(index * 16 + 8),
        length: records.getUint32(index * 16 + 12),
      ),
  };
}

_FaceStyle _styleOf(RandomAccessFile file, Map<String, _TableSpot> tables) {
  final os2 = tables['OS/2'];
  if (os2 != null && os2.length >= 64) {
    final selection = _bytesAt(file, os2.offset + 62, 2).getUint16(0);
    return (
      isBold: selection & _boldStyleBit != 0,
      isItalic: selection & _italicStyleBit != 0,
    );
  }
  final head = tables['head'];
  if (head != null && head.length >= 46) {
    final macStyle = _bytesAt(file, head.offset + 44, 2).getUint16(0);
    return (
      isBold: macStyle & _macBoldBit != 0,
      isItalic: macStyle & _macItalicBit != 0,
    );
  }
  return (isBold: false, isItalic: false);
}

String? _familyNameIn(ByteData table) {
  final count = table.getUint16(2);
  final stringsStart = table.getUint16(4);
  String? bestName;
  var bestRank = 0;
  for (var index = 0; index < count; index++) {
    final record = 6 + index * 12;
    if (record + 12 > table.lengthInBytes) break;
    if (table.getUint16(record + 6) != _familyNameId) continue;
    final platform = table.getUint16(record);
    final rank = _nameRank(platform, table.getUint16(record + 4));
    if (rank <= bestRank) continue;
    final start = stringsStart + table.getUint16(record + 10);
    final end = start + table.getUint16(record + 8);
    if (end > table.lengthInBytes) continue;
    final bytes = Uint8List.sublistView(table, start, end);
    bestName = platform == _macPlatform
        ? latin1.decode(bytes)
        : _utf16BigEndian(bytes);
    bestRank = rank;
  }
  return bestName?.trim();
}

int _nameRank(int platform, int language) {
  if (platform == _windowsPlatform && language == _englishUnitedStates) {
    return 4;
  }
  if (platform == _windowsPlatform) return 3;
  if (platform == _unicodePlatform) return 2;
  if (platform == _macPlatform && language == 0) return 1;
  return 0;
}

String _utf16BigEndian(Uint8List bytes) {
  return String.fromCharCodes([
    for (var index = 0; index + 1 < bytes.length; index += 2)
      (bytes[index] << 8) | bytes[index + 1],
  ]);
}

ByteData _bytesAt(RandomAccessFile file, int offset, int length) {
  file.setPositionSync(offset);
  final bytes = file.readSync(length);
  if (bytes.length < length) {
    throw const FormatException('The font file is cut short.');
  }
  return ByteData.sublistView(bytes);
}
