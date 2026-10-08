import 'dart:io';

/// Hosts pass their own data directory; on its own the package falls back to
/// application support, which on iOS is already the app's own container.
Future<Directory> libraryRoot(String? rootPath, String name) async {
  final base = rootPath ?? _defaultRoot();
  final directory = Directory('$base${Platform.pathSeparator}$name');
  if (!directory.existsSync()) await directory.create(recursive: true);
  return directory;
}

String _defaultRoot() {
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (Platform.isWindows) {
    final local = Platform.environment['LOCALAPPDATA'];
    if (local != null && local.isNotEmpty) return '$local/emulators';
    if (home != null && home.isNotEmpty) return '$home/AppData/Local/emulators';
  } else if (home != null && home.isNotEmpty) {
    return '$home/Library/Application Support/emulators';
  }
  throw StateError('Cannot locate emulator application data; pass rootPath');
}
