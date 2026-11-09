import 'dart:io';
import 'dart:typed_data';

/// Writes [bytes] to `responsive_mirror_exports/` in the working directory
/// (desktop) or the temp directory (mobile) and returns the file path.
Future<String?> savePng(String fileName, Uint8List bytes) async {
  final base = (Platform.isAndroid || Platform.isIOS)
      ? Directory.systemTemp.path
      : Directory.current.path;
  final dir =
      Directory('$base${Platform.pathSeparator}responsive_mirror_exports');
  await dir.create(recursive: true);
  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}
