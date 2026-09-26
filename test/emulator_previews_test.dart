import 'dart:io';

import 'package:emulator_palapa/emulator_palapa.dart';
import 'package:emulator_palapa/src/emulator_previews.dart';
import 'package:emulator_palapa/src/emulator_preview.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Session extends EmulatorSession {
  _Session(String corePath) : super(corePath: corePath, preview: true);

  RomFile? opened;
  bool disposed = false;

  @override
  void play(RomFile rom) => opened = rom;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _Previews extends EmulatorPreviews {
  final created = <_Session>[];

  @override
  EmulatorSession createSession(String corePath) {
    final session = _Session(corePath);
    created.add(session);
    return session;
  }
}

class _Shelf extends EmulatorViewModel {
  _Shelf({required super.libraryRoot});

  final previews = _Previews();

  @override
  List<RomFile> get roms => const [
    RomFile(path: '/first.sfc', title: 'First', sizeBytes: 1),
    RomFile(path: '/second.sfc', title: 'Second', sizeBytes: 1),
  ];

  @override
  EmulatorSession? sessionFor(RomFile rom) => previews.sessionFor(rom);

  @override
  EmulatorSession? retainPreview(RomFile rom) => previews.retain(rom, '/core');

  @override
  void releasePreview(RomFile rom, EmulatorSession? preview) =>
      previews.release(rom, preview);

  @override
  void dispose() {
    previews.dispose();
    super.dispose();
  }
}

void main() {
  const first = RomFile(path: '/first.sfc', title: 'First', sizeBytes: 1);
  const second = RomFile(path: '/second.sfc', title: 'Second', sizeBytes: 1);

  testWidgets('only mounted shelf cards retain preview sessions', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('emulator_previews');
    final model = _Shelf(libraryRoot: root.path);
    await tester.runAsync(model.refresh);

    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ListenableBuilder(
          listenable: model,
          builder: (_, _) =>
              EmulatorShelf(viewModel: model, skin: const EmulatorSkin()),
        ),
      ),
    );
    expect(model.previews.created, hasLength(2));

    model.notifyListeners();
    await tester.pump();
    expect(model.previews.created, hasLength(2));

    await tester.pumpWidget(const SizedBox());
    expect(model.previews.created.every((session) => session.disposed), isTrue);
    model.dispose();
    root.deleteSync(recursive: true);
  });

  test('preview ownership follows replaced sources and releases once', () {
    final root = Directory.systemTemp.createTempSync('preview-owner');
    final one = _Shelf(libraryRoot: root.path);
    final two = _Shelf(libraryRoot: root.path);
    final preview = EmulatorPreview(one, first);
    preview.update(one, first);
    expect(one.previews.created, hasLength(1));

    preview.update(two, second);
    expect(one.previews.created.single.disposed, isTrue);
    expect(two.previews.created.single.opened, second);
    two.previews.stop();
    preview.update(two, second);
    expect(two.previews.created, hasLength(2));
    expect(preview.session, same(two.previews.created.last));

    preview.cancel();
    preview.cancel();
    preview.update(one, first);
    expect(preview.session, isNull);
    expect(two.previews.created.every((session) => session.disposed), isTrue);
    one.dispose();
    two.dispose();
    root.deleteSync(recursive: true);
  });

  test('visible cards start previews and the last reader closes them', () {
    final previews = _Previews();
    addTearDown(previews.dispose);

    final one = previews.retain(first, '/core');
    final again = previews.retain(first, '/core');
    final two = previews.retain(second, '/core');

    expect(one, same(again));
    expect(previews.created, hasLength(2));
    expect(previews.created.map((session) => session.opened), [first, second]);
    expect(previews.created.every((session) => session.preview), isTrue);

    previews.release(first, one);
    expect(previews.created.first.disposed, isFalse);
    previews.release(first, again);
    expect(previews.created.first.disposed, isTrue);
    expect(previews.sessionFor(first), isNull);
    expect(previews.sessionFor(second), same(two));

    previews.release(second, two);
    expect(previews.created.last.disposed, isTrue);
  });

  test('stale releases cannot stop a newly mounted card', () {
    final previews = _Previews();
    addTearDown(previews.dispose);
    final old = previews.retain(first, '/core');
    previews.stop();
    expect(previews.created.single.disposed, isTrue);

    final current = previews.retain(first, '/core');
    previews.release(first, old);
    expect(previews.sessionFor(first), same(current));
    expect(previews.created.last.disposed, isFalse);
  });

  test('missing cores and disposed shelves never open a native session', () {
    final previews = _Previews();
    expect(previews.retain(first, null), isNull);
    final session = previews.retain(first, '/core');
    previews.dispose();
    expect(previews.created.single.disposed, isTrue);
    expect(previews.retain(second, '/core'), isNull);
    previews.release(first, session);
    expect(previews.created, hasLength(1));
  });
}
