import 'dart:io';

import 'package:emulator_palapa/emulator_palapa.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _ButtonSkin extends EmulatorSkin {
  const _ButtonSkin();

  @override
  Widget button(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    EmulatorIcon? icon,
    VoidCallback? onSecondaryTap,
    bool labelled = false,
  }) => GestureDetector(
    key: ValueKey(label),
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    onSecondaryTap: onSecondaryTap,
    child: const SizedBox(width: 24, height: 24),
  );
}

class _PlayingViewModel extends EmulatorViewModel {
  _PlayingViewModel(String root)
    : super(libraryRoot: root, corePath: '$root/missing-core');

  @override
  RomFile get playing =>
      const RomFile(path: '/game.sfc', title: 'Game', sizeBytes: 0);
}

Widget _wrap(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: EmulatorTheme(skin: const _ButtonSkin(), child: child),
);

void main() {
  testWidgets(
    'standalone controls keep display choices and the pad on the right',
    (tester) async {
      final temp = Directory.systemTemp.createTempSync('emulator_transport_');
      final model = _PlayingViewModel(temp.path);
      addTearDown(() {
        model.dispose();
        temp.deleteSync(recursive: true);
      });

      await tester.pumpWidget(
        _wrap(
          Align(
            alignment: Alignment.topCenter,
            child: EmulatorTransport(
              viewModel: model,
              showTrainingData: false,
              showPixelShape: true,
              onPairController: () {},
              leading: const SizedBox(key: ValueKey('host-leading'), width: 24),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('not sharing training data')),
        findsNothing,
      );
      expect(model.sharesTrainingData, isFalse);
      expect(
        tester.getCenter(find.byKey(const ValueKey('Connect controller'))).dx,
        greaterThan(
          tester.getCenter(find.byKey(const ValueKey('host-leading'))).dx,
        ),
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('Connect controller'))).dx,
        greaterThan(
          tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
        ),
      );
      expect(find.text('①'), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('VHS')));
      await tester.pump();
      expect(model.style, DisplayStyle.trinitron);
      expect(find.byKey(const ValueKey('Trinitron')), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('Trinitron')),
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
      expect(model.style, DisplayStyle.vhs);

      await tester.tap(find.byKey(const ValueKey('4:3')));
      await tester.pump();
      expect(model.squarePixels, isTrue);
      expect(find.byKey(const ValueKey('1:1')), findsOneWidget);
    },
  );

  testWidgets(
    'host mutations update controls and fullscreen reports its new state',
    (tester) async {
      final temp = Directory.systemTemp.createTempSync('emulator_transport_');
      final model = _PlayingViewModel(temp.path);
      final fullscreen = <bool>[];
      addTearDown(() {
        model.dispose();
        temp.deleteSync(recursive: true);
      });

      await tester.pumpWidget(
        _wrap(
          Align(
            alignment: Alignment.topCenter,
            child: EmulatorTransport(
              viewModel: model,
              onFullscreen: fullscreen.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      model.cycleStyle();
      await tester.pump();
      expect(find.byKey(const ValueKey('Trinitron')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('Fullscreen')));
      await tester.pump();
      expect(model.fullscreen, isTrue);
      expect(fullscreen, [true]);
      expect(find.byKey(const ValueKey('Leave fullscreen')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('Leave fullscreen')));
      await tester.pump();
      expect(fullscreen, [true, false]);
    },
  );

  testWidgets(
    'a separated screen hides normal controls and retains fullscreen controls',
    (tester) async {
      final temp = Directory.systemTemp.createTempSync('emulator_transport_');
      final model = _PlayingViewModel(temp.path);
      final fullscreen = <bool>[];
      addTearDown(() {
        model.dispose();
        temp.deleteSync(recursive: true);
      });

      await tester.pumpWidget(
        _wrap(
          EmulatorScreen(
            viewModel: model,
            showShelf: false,
            showTransport: false,
            onFullscreen: fullscreen.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EmulatorTransport), findsNothing);

      model.toggleFullscreen();
      await tester.pump();
      expect(find.byType(EmulatorTransport), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('Leave fullscreen')));
      await tester.pump();
      expect(model.fullscreen, isFalse);
      expect(fullscreen, [false]);
      expect(find.byType(EmulatorTransport), findsNothing);
    },
  );

  testWidgets('controls wrap within a narrow host with a selected game', (
    tester,
  ) async {
    final temp = Directory.systemTemp.createTempSync('emulator_transport_');
    final model = _PlayingViewModel(temp.path);
    addTearDown(() {
      model.dispose();
      temp.deleteSync(recursive: true);
    });

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 320,
            child: EmulatorTransport(
              viewModel: model,
              showTrainingData: false,
              showPixelShape: true,
              onPairController: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('①'), findsNWidgets(2));
    expect(find.text('4:3'), findsOneWidget);
    final toolbar = tester.getRect(find.byType(EmulatorTransport));
    for (final glyph in tester.renderObjectList<RenderBox>(
      find.byType(EmulatorGlyph),
    )) {
      final point = glyph.localToGlobal(Offset.zero);
      expect(point.dx, greaterThanOrEqualTo(toolbar.left));
      expect(point.dx + glyph.size.width, lessThanOrEqualTo(toolbar.right));
    }
  });
}
