import 'dart:async';
import 'dart:io';

import 'library_root.dart';

import 'rom_file.dart';

/// The shelf of cartridges in one directory.
///
/// Adding a file copies it in rather than referencing where it came from, so
/// the collection survives the original being moved or a downloads folder
/// being emptied.
class RomLibrary {
  RomLibrary({this.rootPath});

  /// Host apps that keep their own data directory pass one; on its own the
  /// package falls back to application support.
  final String? rootPath;

  Future<Directory> root() async {
    return libraryRoot(rootPath, 'roms');
  }

  Future<List<RomFile>> load() async {
    final directory = await root();
    final files = await directory
        .list(followLinks: false)
        .where((entry) => entry is File && RomFile.isRom(entry.path))
        .cast<File>()
        .toList();
    // Keep the unsuffixed original as the stable visible path.
    files.sort((a, b) {
      final imported = RegExp(r'-imported-\d+\.');
      final rank = (imported.hasMatch(a.path) ? 1 : 0).compareTo(
        imported.hasMatch(b.path) ? 1 : 0,
      );
      return rank == 0 ? a.path.compareTo(b.path) : rank;
    });
    final groups = <List<File>>[];
    for (final file in files) {
      List<File>? duplicate;
      for (final group in groups) {
        if (RomSystem.of(file.path) == RomSystem.of(group.first.path) &&
            await _identical(file, group.first)) {
          duplicate = group;
          break;
        }
      }
      if (duplicate == null) {
        groups.add([file]);
      } else {
        duplicate.add(file);
      }
    }
    return [
      for (final group in groups)
        RomFile(
          path: group.first.path,
          title: RomFile.titleFor(group.first.path),
          sizeBytes: await group.first.length(),
          aliases: List.unmodifiable(group.skip(1).map((file) => file.path)),
        ),
    ]..sort((a, b) => a.title.compareTo(b.title));
  }

  static final _imports = <String, Future<void>>{};

  Future<List<RomFile>> add(Iterable<String> paths) async {
    final incoming = List<String>.of(paths.where(RomFile.isRom));
    final directory = await root();
    final key = directory.absolute.path;
    final previous = _imports[key] ?? Future<void>.value();
    final done = Completer<void>();
    _imports[key] = done.future;
    await previous;
    try {
      var existing = await load();
      for (final path in incoming) {
        final source = File(path);
        var duplicate = false;
        for (final rom in existing) {
          if (RomSystem.of(path) == rom.system &&
              await _identical(source, File(rom.path))) {
            duplicate = true;
            break;
          }
        }
        if (duplicate) continue;
        final name = source.uri.pathSegments.last;
        final dot = name.lastIndexOf('.');
        var destination = File('${directory.path}/$name');
        var suffix = 1;
        while (await destination.exists()) {
          destination = File(
            '${directory.path}/${name.substring(0, dot)}-imported-${suffix++}${name.substring(dot)}',
          );
        }
        await source.copy(destination.path);
        existing = await load();
      }
      return existing;
    } finally {
      done.complete();
      if (identical(_imports[key], done.future))
        unawaited(_imports.remove(key));
    }
  }

  // Compare chunks, not names or lossy hashes; different revisions stay separate.
  static Future<bool> _identical(File a, File b) async {
    if (a.absolute.path == b.absolute.path) return true;
    if (await a.length() != await b.length()) return false;
    final left = await a.open();
    final right = await b.open();
    try {
      while (true) {
        final x = await left.read(65536);
        final y = await right.read(65536);
        if (x.length != y.length) return false;
        if (x.isEmpty) return true;
        for (var i = 0; i < x.length; i++) {
          if (x[i] != y[i]) return false;
        }
      }
    } finally {
      await left.close();
      await right.close();
    }
  }

  Future<List<RomFile>> remove(RomFile rom) async {
    for (final path in rom.allPaths) {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    }
    return load();
  }
}
