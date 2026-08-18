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

    final roms = directory
        .listSync()
        .whereType<File>()
        .where((f) => RomFile.isRom(f.path))
        .map((f) => RomFile.at(f.path))
        .toList();

    return roms..sort((a, b) => a.title.compareTo(b.title));
  }

  Future<List<RomFile>> add(Iterable<String> paths) async {
    final directory = await root();

    await Future.wait(
      paths.where(RomFile.isRom).map((path) async {
        final name = path.split(Platform.pathSeparator).last;
        final destination = '${directory.path}${Platform.pathSeparator}$name';
        if (destination != path) await File(path).copy(destination);
      }),
    );

    return load();
  }

  Future<List<RomFile>> remove(RomFile rom) async {
    final file = File(rom.path);
    if (file.existsSync()) await file.delete();
    return load();
  }
}
