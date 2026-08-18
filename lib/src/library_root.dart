import 'dart:io';

/// Hosts pass their own data directory; on its own the package falls back to
/// application support, which on iOS is already the app's own container.
Future<Directory> libraryRoot(String? rootPath, String name) async {
  final base =
      rootPath ??
      '${Platform.environment['HOME']}/Library/Application Support/emulators';
  final directory = Directory('$base${Platform.pathSeparator}$name');
  if (!directory.existsSync()) await directory.create(recursive: true);
  return directory;
}
