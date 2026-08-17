import 'dart:io';

class RomFile {
  const RomFile({
    required this.path,
    required this.title,
    required this.sizeBytes,
  });

  factory RomFile.at(String path) {
    final file = File(path);
    return RomFile(
      path: path,
      title: titleFor(path),
      sizeBytes: file.existsSync() ? file.lengthSync() : 0,
    );
  }

  final String path;
  final String title;
  final int sizeBytes;

  static const extensions = {'.sfc', '.smc', '.fig', '.swc'};

  static bool isRom(String path) =>
      extensions.contains(_extensionOf(path).toLowerCase());

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    return dot == -1 ? '' : path.substring(dot);
  }

  /// Dump filenames carry release cruft — region codes, revisions and dump
  /// flags — that nobody wants to read off a shelf.
  static String titleFor(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    final stem = dot == -1 ? name : name.substring(0, dot);

    return stem
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String get sizeLabel => sizeBytes >= 1048576
      ? '${(sizeBytes / 1048576).toStringAsFixed(1)} MB'
      : '${(sizeBytes / 1024).round()} KB';

  @override
  bool operator ==(Object other) => other is RomFile && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
