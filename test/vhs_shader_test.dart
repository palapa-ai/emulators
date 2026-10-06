import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('VHS keeps grayscale edges free of saturated color corruption', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final sourceRecorder = ui.PictureRecorder();
      final sourceCanvas = ui.Canvas(sourceRecorder);
      sourceCanvas.drawColor(const ui.Color(0xff000000), ui.BlendMode.src);
      for (var x = 16; x < 256; x += 32) {
        sourceCanvas.drawRect(
          ui.Rect.fromLTWH(x.toDouble(), 0, 16, 224),
          ui.Paint()..color = const ui.Color(0xffffffff),
        );
      }
      final picture = sourceRecorder.endRecording();
      final source = await picture.toImage(256, 224);
      picture.dispose();
      final program = await ui.FragmentProgram.fromAsset('shaders/vhs.frag');
      final shader = program.fragmentShader();
      try {
        for (final seconds in [0.0, 17.2, 3600.0]) {
          shader
            ..setFloat(0, 256)
            ..setFloat(1, 224)
            ..setFloat(2, seconds)
            ..setFloat(3, 256)
            ..setFloat(4, 224)
            ..setImageSampler(0, source);
          final recorder = ui.PictureRecorder();
          ui.Canvas(recorder).drawRect(
            const ui.Rect.fromLTWH(0, 0, 256, 224),
            ui.Paint()..shader = shader,
          );
          final rendered = recorder.endRecording();
          final image = await rendered.toImage(256, 224);
          rendered.dispose();
          final pixels = (await image.toByteData())!.buffer.asUint8List();
          image.dispose();
          var largestColorDifference = 0;
          var darkest = 255;
          var brightest = 0;
          for (var i = 0; i < pixels.length; i += 4) {
            final channels = [pixels[i], pixels[i + 1], pixels[i + 2]];
            final high = channels.reduce(math.max);
            final low = channels.reduce(math.min);
            largestColorDifference = math.max(
              largestColorDifference,
              high - low,
            );
            darkest = math.min(darkest, low);
            brightest = math.max(brightest, high);
            expect(pixels[i + 3], 255);
          }
          expect(
            largestColorDifference,
            lessThan(40),
            reason: 'grayscale at $seconds seconds',
          );
          expect(darkest, lessThan(20));
          expect(brightest, greaterThan(150));
        }
      } finally {
        shader.dispose();
        source.dispose();
      }
    });
  });
}
