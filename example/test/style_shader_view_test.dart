import 'dart:ui' as ui;

import 'package:emulator_palapa/emulator_palapa.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'all filters compile and render; CRT corners curve and projector animates',
    (tester) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 32, 24),
        Paint()..color = const Color(0xfff08040),
      );
      canvas.drawRect(
        const Rect.fromLTWH(8, 6, 16, 12),
        Paint()..color = const Color(0xff40a0e0),
      );
      final picture = recorder.endRecording();
      final frame = await tester.runAsync(() => picture.toImage(32, 24));
      picture.dispose();
      final key = GlobalKey();
      final pixels = <DisplayStyle, List<int>>{};

      for (final style in DisplayStyle.values) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 128,
                  height: 96,
                  child: StyleShaderView(frame: frame!, style: style),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 17));
        expect(
          find.byType(RawImage),
          findsNothing,
          reason: '${style.label} should use its compiled shader',
        );
        final image = await tester.runAsync(
          () =>
              (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
                  .toImage(),
        );
        final data = await tester.runAsync(() => image!.toByteData());
        pixels[style] = data!.buffer.asUint8List().toList();
        image!.dispose();
        expect(tester.takeException(), isNull, reason: style.label);
      }

      for (final style in [DisplayStyle.arcade, DisplayStyle.homeTv]) {
        final data = pixels[style]!;
        expect(data.take(3), [
          0,
          0,
          0,
        ], reason: '${style.label} should have clipped CRT corners');
        const center = (48 * 128 + 64) * 4;
        expect(data.sublist(center, center + 3).any((v) => v > 30), isTrue);
      }
      expect(
        pixels[DisplayStyle.lcd],
        isNot(equals(pixels[DisplayStyle.oled])),
      );
      expect(
        pixels[DisplayStyle.projector],
        isNot(equals(pixels[DisplayStyle.homeTv])),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 128,
            height: 96,
            child: StyleShaderView(
              frame: frame!,
              style: DisplayStyle.projector,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 17));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 128,
            height: 96,
            child: StyleShaderView(frame: frame, style: DisplayStyle.oled),
          ),
        ),
      );
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
      frame.dispose();
    },
  );
}
