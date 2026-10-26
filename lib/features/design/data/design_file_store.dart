import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../../core/file_names.dart';
import 'models/label_design.dart';

const String designFileExtension = 'labeldesign';

class DesignFileStore {
  const DesignFileStore();

  Future<LabelDesign> readDesign(String path) async {
    final text = await File(path).readAsString();
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('This is not a Barcode Labeler design file.');
    }
    return LabelDesign.fromJson(json);
  }

  Future<void> writeDesign(String path, LabelDesign design) async {
    final temporary = File('$path.saving');
    await temporary.writeAsBytes(_encodeDesign(design), flush: true);
    await temporary.rename(path);
  }

  Future<String?> pickDesignToOpen() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Open a label design',
      type: FileType.custom,
      allowedExtensions: const [designFileExtension],
    );
    return file?.path;
  }

  Future<String?> saveDesignWithDialog(LabelDesign design) async {
    final savedUri = await FilePicker.saveFile(
      dialogTitle: 'Save label design',
      fileName: '${safeFileName(design.name)}.$designFileExtension',
      bytes: _encodeDesign(design),
    );
    if (savedUri == null || savedUri.scheme != 'file') return null;
    return _withDesignExtension(savedUri.toFilePath());
  }

  Future<String> _withDesignExtension(String path) async {
    if (p.extension(path).toLowerCase() == '.$designFileExtension') {
      return path;
    }
    final renamed = await File(path).rename('$path.$designFileExtension');
    return renamed.path;
  }

  Uint8List _encodeDesign(LabelDesign design) {
    const encoder = JsonEncoder.withIndent('  ');
    return Uint8List.fromList(utf8.encode(encoder.convert(design.toJson())));
  }
}
