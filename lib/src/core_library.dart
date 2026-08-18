import 'dart:io';

import 'library_root.dart';

/// Where libretro cores are kept, alongside the cartridges.
///
/// Cores are a separate build artefact — often not shipped inside the app at
/// all — so the package looks for whatever has been dropped in rather than
/// requiring the host to know a path.
class CoreLibrary {
  CoreLibrary({this.rootPath});

  final String? rootPath;

  static const _extensions = {'.dylib', '.so', '.dll'};

  Future<Directory> root() async {
    return libraryRoot(rootPath, 'cores');
  }

  Future<List<String>> installed() async {
    final directory = await root();

    final cores =
        directory
            .listSync()
            .whereType<File>()
            .map((f) => f.path)
            .where((p) => _extensions.any((e) => p.toLowerCase().endsWith(e)))
            .toList()
          ..sort();

    return cores;
  }

  Future<String?> first() async => (await installed()).firstOrNull;
}
