import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Copies the export into `<documents>/exports` so the file stays on the device.
Future<String?> saveExportFile(String fileName, List<int> bytes) async {
  try {
    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory('${documents.path}${Platform.pathSeparator}exports');
    if (!folder.existsSync()) folder.createSync(recursive: true);
    final file = File('${folder.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}