import 'package:emulator_palapa/emulator_palapa.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _game = RomFile(path: '/fixture/game.smc', title: 'Game 0', sizeBytes: 1);

class _Console extends EmulatorViewModel {
  _Console() : super(corePath: '/missing/core');

  bool active = true;
  int pauses = 0;
  int? saved;
  int? loaded;
  RomFile? loadedFrom;
  RomFile? chosen;
  bool muted = false;
  List<RomFile> games = [_game];

  @override
  Future<void> refresh() async {}
  @override
  RomFile? get playing => active ? _game : null;
  @override
  List<RomFile> get roms => games;
  @override
  List<PadElement> get padLog => [.a, .left, .start];
  @override
  bool get isMuted => muted;
  @override
  void toggleMuted() {
    muted = !muted;
    notifyListeners();
  }

  @override
  void togglePause() => pauses++;
  @override
  bool hasState(RomFile rom, int slot) => slot == 1;
  @override
  Future<void> saveState(int slot) async {
    saved = slot;
  }

  @override
  Future<void> loadState(int slot, {RomFile? from}) async {
    loaded = slot;
    loadedFrom = from;
  }

  @override
  Future<void> play(RomFile rom) async {
    chosen = rom;
  }
}

Widget _wrap(Widget child, {Size size = const Size(900, 600)}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(size: size, child: child),
      ),
    );

Finder _glyph(EmulatorIcon icon) =>
    find.byWidgetPredicate((w) => w is EmulatorGlyph && w.icon == icon);

void main() {
  late _Console console;
  setUp(() => console = _Console());
  tearDown(() => console.dispose());

  test(
    'cycles through the requested filters and back to Raw in both directions',
    () {
      expect(console.style, isNull);
      final labels = <String>[];
      for (var i = 0; i < 10; i++) {
        labels.add(console.style?.label ?? 'Raw');
        console.cycleStyle();
      }
      expect(labels, [
        'Raw',
        'Game Boy',
        'NES',
        'VHS',
        'Arcade',
        'Home TV',
        'Projector',
        'Dot Matrix',
        'LCD',
        'OLED',
      ]);
      expect(console.style, isNull);
      console.cycleStyle(reverse: true);
      expect(console.style, DisplayStyle.oled);
      for (var i = 0; i < 9; i++) {
        console.cycleStyle(reverse: true);
      }
      expect(console.style, isNull);
    },
  );

  testWidgets(
    'shared Controls shows live demo ticker, pairing and sharing state',
    (tester) async {
      var paired = false;
      await tester.pumpWidget(
        _wrap(
          ControlsView(
            viewModel: console,
            onPairController: () => paired = true,
          ),
        ),
      );
      expect(find.text('Controller #1'), findsOneWidget);
      expect(find.text('START'), findsOneWidget);
      expect(find.text('Z'), findsNothing);
      await tester.tap(find.text('Connect controller'));
      expect(paired, isTrue);
      await tester.tap(find.text('not sharing training data'));
      await tester.pump();
      expect(console.sharesTrainingData, isTrue);
      expect(find.text('sharing training data'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'square slots distinguish occupied loads and preserve save/load behavior',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          Row(
            children: [
              StateSlots(viewModel: console),
              StateSlots(viewModel: console, rom: _game, saving: false),
            ],
          ),
        ),
      );
      expect(find.text('①'), findsNothing);
      expect(find.text('1'), findsNWidgets(2));
      final slot = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('1').first,
              matching: find.byType(Container),
            )
            .first,
      );
      expect(slot.constraints!.maxWidth, 24);
      expect(slot.constraints!.maxHeight, 24);
      await tester.tap(find.text('2').first);
      expect(console.saved, 2);
      await tester.tap(find.text('2').last);
      expect(console.loaded, isNull);
      await tester.tap(find.text('1').last);
      expect(console.loaded, 1);
      expect(console.loadedFrom, _game);
      final occupied = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.label == 'Load slot 1')
          .single;
      final empty = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.label == 'Load slot 2')
          .single;
      expect(occupied.properties.selected, isTrue);
      expect(empty.properties.enabled, isFalse);
    },
  );

  testWidgets(
    'slot hover explains the action and enabled slots have hand cursors',
    (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (_) => Center(child: StateSlots(viewModel: console)),
              ),
            ],
          ),
        ),
      );
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      await pointer.moveTo(tester.getCenter(find.text('1')));
      await tester.pump();
      expect(find.text('Save slot 1'), findsOneWidget);
      expect(
        tester
            .widgetList<MouseRegion>(
              find.ancestor(
                of: find.text('1'),
                matching: find.byType(MouseRegion),
              ),
            )
            .any((r) => r.cursor == SystemMouseCursors.click),
        isTrue,
      );
      await pointer.removePointer();
      await tester.pump();
      expect(find.text('Save slot 1'), findsNothing);
    },
  );

  testWidgets(
    'toolbar has filter icon and label, audio last, and no host fullscreen or aspect duplicate',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          EmulatorScreen(
            viewModel: console,
            showShelf: false,
            showFullscreen: false,
            showTrainingData: false,
          ),
        ),
      );
      expect(_glyph(EmulatorIcon.filter), findsOneWidget);
      expect(find.text('Raw'), findsOneWidget);
      expect(_glyph(EmulatorIcon.fullscreen), findsNothing);
      expect(find.text('4:3'), findsNothing);
      expect(
        tester.getCenter(_glyph(EmulatorIcon.sound)).dx,
        greaterThan(tester.getCenter(_glyph(EmulatorIcon.reset)).dx),
      );
      await tester.tap(_glyph(EmulatorIcon.sound));
      await tester.pump();
      expect(console.isMuted, isTrue);
      final picture = find.byKey(const ValueKey('emulator-picture'));
      expect(
        tester
            .widgetList<MouseRegion>(
              find.ancestor(of: picture, matching: find.byType(MouseRegion)),
            )
            .any((r) => r.cursor == SystemMouseCursors.click),
        isTrue,
      );
      await tester.tap(picture);
      expect(console.pauses, 1);
      console.active = false;
      console.notifyListeners();
      await tester.pump();
      expect(picture, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide collection is a grid and compact collections are lazy horizontal shelves',
    (tester) async {
      console.games = List.generate(
        40,
        (i) => RomFile(path: '/fixture/$i.smc', title: 'Game $i', sizeBytes: 1),
      );
      await tester.pumpWidget(
        _wrap(EmulatorShelf(viewModel: console, skin: const EmulatorSkin())),
      );
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Game 39'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        _wrap(
          EmulatorShelf(viewModel: console, skin: const EmulatorSkin()),
          size: const Size(400, 500),
        ),
      );
      expect(find.byType(GridView), findsNothing);
      expect(
        tester.widget<ListView>(find.byType(ListView)).scrollDirection,
        Axis.horizontal,
      );
      expect(find.text('Game 39'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Game 39'),
        800,
        scrollable: find.byType(Scrollable),
        maxScrolls: 20,
      );
      await tester.drag(find.byType(ListView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Game 39'));
      expect(console.chosen!.title, 'Game 39');
      await tester.pumpWidget(
        _wrap(
          EmulatorShelf(viewModel: console, skin: const EmulatorSkin()),
          size: const Size(800, 220),
        ),
      );
      expect(find.byType(GridView), findsNothing);
      expect(
        tester.widget<ListView>(find.byType(ListView)).scrollDirection,
        Axis.horizontal,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
