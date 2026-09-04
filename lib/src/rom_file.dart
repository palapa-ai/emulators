import 'dart:io';

import 'rom_catalog.dart';

/// Which machine a cartridge belongs to, taken from its extension — the
/// shelf is grouped by system even when only one of them has anything in it.
/// Only machines a bundled core can actually run are listed; NES and N64
/// return when their cores do.
enum RomSystem {
  snes('SNES', {'.sfc', '.smc', '.fig', '.swc'});

  const RomSystem(this.label, this.extensions);

  final String label;
  final Set<String> extensions;

  static RomSystem? of(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) return null;

    final extension = path.substring(dot).toLowerCase();
    for (final system in values) {
      if (system.extensions.contains(extension)) return system;
    }
    return null;
  }
}

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

  String? get note => RomCatalog.forTitle(title)?.note;
  int? get year => RomCatalog.forTitle(title)?.year;

  static final extensions = {
    for (final system in RomSystem.values) ...system.extensions,
  };

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

  RomSystem? get system => RomSystem.of(path);

  String get fileName => path.split(Platform.pathSeparator).last;

  String get sizeLabel => sizeBytes >= 1048576
      ? '${(sizeBytes / 1048576).toStringAsFixed(1)} MB'
      : '${(sizeBytes / 1024).round()} KB';

  @override
  bool operator ==(Object other) => other is RomFile && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
