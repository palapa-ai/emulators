import 'dart:async';
import 'dart:io';

import 'package:emulator_palapa/emulator_palapa.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _SlotViewModel extends EmulatorViewModel {
  _SlotViewModel(String root)
    : super(libraryRoot: root, corePath: '$root/missing-core');

  final saves = <int>[];
  final loads = <(int, RomFile?)>[];
  final results = <Completer<bool>>[];
  RomFile? active = const RomFile(
    path: '/game.sfc',
    title: 'Game',
    sizeBytes: 0,
  );
  bool occupied = false;

  @override
  RomFile? get playing => active;

  @override
  bool hasState(RomFile rom, int slot) => occupied;

  @override
  Future<bool> saveState(int slot) {
    saves.add(slot);
    final result = Completer<bool>();
    results.add(result);
    return result.future;
  }

  @override
  Future<bool> loadState(int slot, {RomFile? from}) {
    loads.add((slot, from));
    final result = Completer<bool>();
    results.add(result);
    return result.future;
  }
}

Widget _wrap(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

Finder _glyph(EmulatorIcon icon) => find.byWidgetPredicate(
  (widget) => widget is EmulatorGlyph && widget.icon == icon,
);

void main() {
  for (final saving in [true, false]) {
    testWidgets(
      '${saving ? 'save' : 'load'} confirms only after success without changing slot geometry',
      (tester) async {
        final temp = Directory.systemTemp.createTempSync('emulator_slots_');
        final model = _SlotViewModel(temp.path);
        addTearDown(() {
          model.dispose();
          temp.deleteSync(recursive: true);
        });
        await tester.pumpWidget(
          _wrap(StateSlots(viewModel: model, saving: saving)),
        );
        await tester.pumpAndSettle();
        final before = tester.getRect(find.byType(StateSlots));
        final first = tester.getRect(find.text('①'));
        final second = tester.getRect(find.text('②'));

        await tester.tap(find.text('①'));
        await tester.pump();
        expect(_glyph(EmulatorIcon.check), findsNothing);
        expect(model.results, hasLength(1));
        await tester.tap(find.text('①'));
        expect(model.results, hasLength(1));
        model.results.single.complete(true);
        await tester.idle();
        await tester.pump();

        expect(_glyph(EmulatorIcon.check), findsOneWidget);
        expect(
          _glyph(saving ? EmulatorIcon.save : EmulatorIcon.load),
          findsOneWidget,
        );
        expect(tester.getRect(find.byType(StateSlots)), before);
        expect(tester.getRect(find.text('①')), first);
        expect(tester.getRect(find.text('②')), second);
        await tester.pump(const Duration(milliseconds: 1499));
        expect(_glyph(EmulatorIcon.check), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        expect(_glyph(EmulatorIcon.check), findsNothing);
        expect(tester.getRect(find.text('①')), first);
      },
    );

    testWidgets(
      '${saving ? 'save' : 'load'} failure never confirms even with an existing slot',
      (tester) async {
        final temp = Directory.systemTemp.createTempSync('emulator_slots_');
        final model = _SlotViewModel(temp.path)..occupied = true;
        addTearDown(() {
          model.dispose();
          temp.deleteSync(recursive: true);
        });
        await tester.pumpWidget(
          _wrap(StateSlots(viewModel: model, saving: saving)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('②'));
        model.results.single.complete(false);
        await tester.idle();
        await tester.pump();
        expect(_glyph(EmulatorIcon.check), findsNothing);
        expect(find.text('②'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'leaving during an operation or confirmation has no delayed state update',
    (tester) async {
      final temp = Directory.systemTemp.createTempSync('emulator_slots_');
      final model = _SlotViewModel(temp.path);
      addTearDown(() {
        model.dispose();
        temp.deleteSync(recursive: true);
      });
      await tester.pumpWidget(_wrap(StateSlots(viewModel: model)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('①'));
      await tester.pumpWidget(_wrap(const SizedBox()));
      model.results.single.complete(true);
      await tester.idle();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_wrap(StateSlots(viewModel: model)));
      await tester.tap(find.text('②'));
      model.results.last.complete(true);
      await tester.idle();
      await tester.pump();
      expect(_glyph(EmulatorIcon.check), findsOneWidget);
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a completed operation cannot confirm a different cartridge', (
    tester,
  ) async {
    final temp = Directory.systemTemp.createTempSync('emulator_slots_');
    final model = _SlotViewModel(temp.path);
    addTearDown(() {
      model.dispose();
      temp.deleteSync(recursive: true);
    });
    await tester.pumpWidget(_wrap(StateSlots(viewModel: model)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('①'));
    model.active = const RomFile(
      path: '/other.sfc',
      title: 'Other',
      sizeBytes: 0,
    );
    await tester.pumpWidget(_wrap(StateSlots(viewModel: model)));
    model.results.single.complete(true);
    await tester.idle();
    await tester.pump();
    expect(_glyph(EmulatorIcon.check), findsNothing);
  });

  testWidgets(
    'a new operation clears its previous confirmation until it succeeds',
    (tester) async {
      final temp = Directory.systemTemp.createTempSync('emulator_slots_');
      final model = _SlotViewModel(temp.path);
      addTearDown(() {
        model.dispose();
        temp.deleteSync(recursive: true);
      });
      await tester.pumpWidget(_wrap(StateSlots(viewModel: model)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('③'));
      model.results.single.complete(true);
      await tester.idle();
      await tester.pump();
      expect(_glyph(EmulatorIcon.check), findsOneWidget);

      await tester.tap(_glyph(EmulatorIcon.check));
      await tester.pump();
      expect(model.results, hasLength(2));
      expect(_glyph(EmulatorIcon.check), findsNothing);
      model.results.last.complete(false);
      await tester.idle();
      await tester.pump(const Duration(seconds: 2));
      expect(_glyph(EmulatorIcon.check), findsNothing);
    },
  );
}
