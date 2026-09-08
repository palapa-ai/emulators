@TestOn('mac-os')
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:emulator_palapa/src/emulator_collection.dart';
import 'package:emulator_palapa/src/emulator_session.dart';
import 'package:emulator_palapa/src/native_memory.dart';
import 'package:emulator_palapa/src/rom_file.dart';
import 'package:emulator_palapa/src/ui/emulator_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture = Directory.systemTemp.createTempSync('emulator_lifecycle');
  final core = '${fixture.path}/counter.dylib';
  final events = File('${fixture.path}/events');
  final host = '${fixture.path}/host.dylib';

  setUpAll(() async {
    final include =
        '${Directory.current.path}/macos/emulator_palapa/Sources/emulators_host';
    for (final args in [
      [
        '-dynamiclib',
        '-I$include/include',
        '-DEVENTS_PATH="${events.path}"',
        'test/fixtures/counter_core.c',
        '-o',
        core,
      ],
      [
        '-dynamiclib',
        '-I$include/include',
        '$include/libretro_host.c',
        '-framework',
        'AudioToolbox',
        '-o',
        host,
      ],
    ]) {
      final result = await Process.run('clang', args);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    }
    final open = DynamicLibrary.process()
        .lookupFunction<
          Pointer<Void> Function(Pointer<Utf8>, Int),
          Pointer<Void> Function(Pointer<Utf8>, int)
        >('dlopen');
    final path = host.toNative();
    try {
      expect(open(path, 0x2 | 0x8), isNot(nullptr));
    } finally {
      release(path);
    }
  });

  tearDownAll(() => fixture.deleteSync(recursive: true));

  List<RomFile> roms(String name, int count) => List.generate(count, (index) {
    final file = File('${fixture.path}/$name-$index.sfc')
      ..writeAsBytesSync([index + 1]);
    return RomFile.at(file.path);
  });

  int frame(EmulatorSession session) {
    final bytes = session.saveState();
    expect(bytes, isNotNull);
    return ByteData.sublistView(
      bytes ?? Uint8List(8),
    ).getUint32(0, Endian.host);
  }

  Future<void> frames(WidgetTester tester, [int count = 4]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
  }

  testWidgets(
    'three core handles rotate ROMs and preserve their transient state',
    (tester) async {
      events.writeAsStringSync('');
      final library = roms('rotate', 6);
      final collection = EmulatorCollection(corePath: core)..setRoms(library);
      addTearDown(collection.dispose);
      await frames(tester);
      final first = collection.sessionFor(library.first);
      expect(first, isNotNull);
      final before = frame(first ?? collection.session);
      expect(before, greaterThan(0));

      await tester.pump(EmulatorCollection.previewTurn);
      await frames(tester);
      expect(collection.sessionFor(library.first), isNull);
      expect(File('${library.first.path}.state5').existsSync(), isFalse);
      await collection.play(library.last);
      await frames(tester);

      for (var turn = 0; turn < 8; turn++) {
        await tester.pump(EmulatorCollection.previewTurn);
        final returned = collection.sessionFor(library.first);
        if (returned != null) {
          expect(frame(returned), greaterThanOrEqualTo(before));
        }
        await frames(tester);
      }
      final lines = events.readAsLinesSync();
      expect(lines.where((line) => line.startsWith('open ')), hasLength(3));
      expect(lines.where((line) => line == 'restore 1'), isNotEmpty);
      expect(lines.where((line) => line.startsWith('close ')), isEmpty);
      collection.dispose();
      expect(
        events.readAsLinesSync().where((line) => line.startsWith('close ')),
        hasLength(3),
      );
      await tester.pump(EmulatorCollection.previewTurn);
      expect(
        events.readAsLinesSync().where((line) => line.startsWith('open ')),
        hasLength(3),
      );
    },
  );

  testWidgets(
    'visited games stop advancing and resume without touching manual slots',
    (tester) async {
      final library = roms('visited', 4);
      final manual = File('${library.first.path}.state1')
        ..writeAsBytesSync([4, 3, 2, 1]);
      final collection = EmulatorCollection(corePath: core)
        ..setRoms(library, lastPlayed: library[2]);
      addTearDown(collection.dispose);
      expect(collection.sessionFor(library.first), isNull);
      expect(collection.sessionFor(library[2]), isNull);
      await collection.play(library.first);
      await frames(tester);
      final before = frame(collection.session);
      await collection.play(library[1]);
      final parked = File('${library.first.path}.state5').readAsBytesSync();
      expect(ByteData.sublistView(parked).getUint32(0, Endian.host), before);

      await tester.pump(EmulatorCollection.previewTurn * 2);
      await frames(tester);
      expect(collection.sessionFor(library.first), isNull);
      expect(File('${library.first.path}.state5').readAsBytesSync(), parked);
      await collection.play(library.first);
      expect(frame(collection.session), before);
      expect(manual.readAsBytesSync(), [4, 3, 2, 1]);
      collection.dispose();

      final reopened = EmulatorCollection(corePath: core)..setRoms(library);
      addTearDown(reopened.dispose);
      expect(reopened.sessionFor(library.first), isNull);
      expect(reopened.sessionFor(library[1]), isNull);
      await reopened.play(library.first);
      expect(frame(reopened.session), before);
      reopened.dispose();
    },
  );

  testWidgets('an invalid resume state is preserved instead of overwritten', (
    tester,
  ) async {
    final library = roms('invalid', 1);
    final saved = File('${library.first.path}.state5')
      ..writeAsBytesSync([1, 2, 3, 4]);
    final collection = EmulatorCollection(corePath: core)..setRoms(library);
    await collection.play(library.first);
    expect(collection.session.isRunning, isFalse);
    expect(collection.sessionFor(library.first), isNull);
    collection.dispose();
    expect(saved.readAsBytesSync(), [1, 2, 3, 4]);
  });

  testWidgets('an unreadable resume state keeps the previous game checkpoint', (
    tester,
  ) async {
    final library = roms('unreadable', 2);
    final saved = File('${library.last.path}.state5')
      ..writeAsBytesSync(Uint8List(8));
    final collection = EmulatorCollection(corePath: core)..setRoms(library);
    await collection.play(library.first);
    await frames(tester);
    final before = frame(collection.session);
    expect(Process.runSync('chmod', ['000', saved.path]).exitCode, 0);
    try {
      await collection.play(library.last);
      expect(collection.session.isRunning, isFalse);
      final previous = File('${library.first.path}.state5').readAsBytesSync();
      expect(ByteData.sublistView(previous).getUint32(0, Endian.host), before);
    } finally {
      Process.runSync('chmod', ['600', saved.path]);
      collection.dispose();
    }
    expect(saved.readAsBytesSync(), Uint8List(8));
  });

  testWidgets(
    'slot outcomes reflect native success and preserve a failed save',
    (tester) async {
      final root = Directory('${fixture.path}/slots')..createSync();
      final directory = Directory('${root.path}/roms')..createSync();
      final file = File('${directory.path}/slot.sfc')..writeAsBytesSync([1]);
      final rom = RomFile.at(file.path);
      final model = EmulatorViewModel(corePath: core, libraryRoot: root.path);
      addTearDown(model.dispose);
      await tester.runAsync(model.refresh);
      await model.play(rom);
      await frames(tester);
      final before = frame(model.session);
      expect(await tester.runAsync(() => model.saveState(1)), isTrue);
      final saved = File('${rom.path}.state1').readAsBytesSync();
      model.reset();
      expect(frame(model.session), 0);
      expect(await tester.runAsync(() => model.loadState(1)), isTrue);
      expect(frame(model.session), before);
      expect(await model.loadState(2), isFalse);

      final blocked = Directory('${rom.path}.state1.tmp')..createSync();
      expect(await tester.runAsync(() => model.saveState(1)), isFalse);
      expect(File('${rom.path}.state1').readAsBytesSync(), saved);
      blocked.deleteSync();
      File('${rom.path}.state2').writeAsBytesSync([1, 2]);
      expect(await tester.runAsync(() => model.loadState(2)), isFalse);
      model.dispose();
    },
  );

  testWidgets('disposing during frame decoding releases every core', (
    tester,
  ) async {
    events.writeAsStringSync('');
    final library = roms('dispose', 3);
    final collection = EmulatorCollection(corePath: core)..setRoms(library);
    await collection.play(library.last);
    await tester.pump(const Duration(milliseconds: 20));
    collection.dispose();
    await frames(tester);
    final lines = events.readAsLinesSync();
    expect(lines.where((line) => line.startsWith('open ')), hasLength(3));
    expect(lines.where((line) => line.startsWith('close ')), hasLength(3));
  });
}
