import 'dart:io';

import 'package:emulator_palapa/src/rom_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late RomLibrary library;
  setUp(() {
    root = Directory.systemTemp.createTempSync('rom-dedup-');
    library = RomLibrary(rootPath: root.path);
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'exact duplicates collapse while distinct revisions stay visible',
    () async {
      final dir = await library.root();
      final original = File('${dir.path}/Lion King.sfc')
        ..writeAsBytesSync([1, 2, 3]);
      final duplicate = File('${dir.path}/Lion King-imported-1.sfc')
        ..writeAsBytesSync([1, 2, 3]);
      File('${dir.path}/Lion King (Rev 2).sfc').writeAsBytesSync([1, 2, 4]);
      File('${original.path}.state1').writeAsBytesSync([11]);
      File('${duplicate.path}.state2').writeAsBytesSync([22]);
      File('${duplicate.path}.png').writeAsBytesSync([33]);
      final roms = await library.load();
      expect(roms, hasLength(2));
      final merged = roms.singleWhere((rom) => rom.path == original.path);
      expect(merged.aliases, [duplicate.path]);
      expect(merged.existingSidecar('.state1'), '${original.path}.state1');
      expect(merged.existingSidecar('.state2'), '${duplicate.path}.state2');
      expect(merged.existingSidecar('.png'), '${duplicate.path}.png');
      expect(duplicate.existsSync(), isTrue);
    },
  );

  test(
    'reimport and overlapping adds reuse identical bytes, never overwrite revisions',
    () async {
      final first = Directory('${root.path}/first')..createSync();
      final second = Directory('${root.path}/second')..createSync();
      final a = File('${first.path}/Game.sfc')..writeAsBytesSync([1, 2, 3]);
      final b = File('${second.path}/Game.sfc')..writeAsBytesSync([1, 2, 4]);
      await Future.wait([
        library.add([a.path]),
        library.add([a.path]),
      ]);
      expect(await library.load(), hasLength(1));
      await library.add([b.path]);
      final loaded = await library.load();
      expect(loaded, hasLength(2));
      expect(File(loaded.first.path).readAsBytesSync(), [1, 2, 3]);
      expect(
        loaded.map((rom) => File(rom.path).readAsBytesSync().last).toSet(),
        {3, 4},
      );
    },
  );

  test('an import failure does not poison the next import', () async {
    await expectLater(
      library.add(['${root.path}/missing.sfc']),
      throwsA(isA<FileSystemException>()),
    );
    final file = File('${root.path}/Valid.sfc')..writeAsBytesSync([7]);
    expect(await library.add([file.path]), hasLength(1));
  });

  test(
    'different filenames reuse content identity and newest alias saves remain readable',
    () async {
      final incoming = File('${root.path}/Renamed.sfc')
        ..writeAsBytesSync([3, 2, 1]);
      final dir = await library.root();
      final original = File('${dir.path}/Original.sfc')
        ..writeAsBytesSync([3, 2, 1]);
      expect(await library.add([incoming.path]), hasLength(1));
      final alias = File('${dir.path}/Original-imported-1.sfc')
        ..writeAsBytesSync([3, 2, 1]);
      final older = File('${original.path}.state1')..writeAsBytesSync([10]);
      older.setLastModifiedSync(DateTime(2020));
      final newer = File('${alias.path}.state1')..writeAsBytesSync([20]);
      final merged = (await library.load()).single;
      expect(merged.path, original.path);
      expect(merged.existingSidecar('.state1'), newer.path);
      expect(older.readAsBytesSync(), [10]);
      expect(newer.readAsBytesSync(), [20]);
      expect(alias.existsSync(), isTrue);
    },
  );
}
