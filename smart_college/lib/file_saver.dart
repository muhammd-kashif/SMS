import 'file_saver_stub.dart' if (dart.library.io) 'file_saver_io.dart' as impl;

/// Writes a generated export into the app documents folder. Returns null on web.
Future<String?> saveExportFile(String fileName, List<int> bytes) => impl.saveExportFile(fileName, bytes);