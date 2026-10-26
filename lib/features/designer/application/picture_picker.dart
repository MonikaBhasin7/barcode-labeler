import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

class PickedPicture {
  const PickedPicture({required this.bytes, required this.widthOverHeight});

  final Uint8List bytes;
  final double widthOverHeight;
}

class PictureReadException implements Exception {
  const PictureReadException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<PickedPicture?> pickPictureFromDisk() async {
  final file = await FilePicker.pickFile(
    dialogTitle: 'Choose a picture or logo',
    type: FileType.custom,
    allowedExtensions: const ['png', 'jpg', 'jpeg'],
  );
  final path = file?.path;
  if (path == null) return null;
  final bytes = await File(path).readAsBytes();
  return PickedPicture(
    bytes: bytes,
    widthOverHeight: await _widthOverHeightOf(bytes),
  );
}

Future<double> _widthOverHeightOf(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ratio = frame.image.width / frame.image.height;
    frame.image.dispose();
    codec.dispose();
    return ratio;
  } on Exception {
    throw const PictureReadException(
      'This picture could not be opened. Please use a PNG or JPG file.',
    );
  }
}
