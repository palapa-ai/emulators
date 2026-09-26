import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'NES output uses a 256 by 240 grid and keeps decoded palette colors',
    () async {
      final source = ui.PictureRecorder();
      final canvas = ui.Canvas(source);
      const colors = [0xff545454, 0xff001e74, 0xff982220, 0xff38b4cc];
      List.generate(480, (y) => y).forEach((y) {
        List.generate(512, (x) => x).forEach((x) {
          canvas.drawRect(
            ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
            ui.Paint()
              ..color = ui.Color(
                x < 128
                    ? 0xff010101
                    : colors[(x ~/ 3 + y ~/ 3) % colors.length],
              ),
          );
        });
      });
      final sourcePicture = source.endRecording();
      final frame = await sourcePicture.toImage(512, 480);
      sourcePicture.dispose();
      final program = await ui.FragmentProgram.fromAsset('shaders/crt.frag');
      final shader = program.fragmentShader();
      const uniforms = <double>[
        512,
        480,
        0,
        512,
        480,
        256,
        240,
        0,
        1,
        0,
        1,
        0,
        1,
        0,
        1,
        1,
        1,
        1,
        5,
        0,
        0,
        0,
      ];
      uniforms.indexed.forEach((value) => shader.setFloat(value.$1, value.$2));
      shader.setImageSampler(0, frame);
      final target = ui.PictureRecorder();
      ui.Canvas(target).drawRect(
        const ui.Rect.fromLTWH(0, 0, 512, 480),
        ui.Paint()..shader = shader,
      );
      final picture = target.endRecording();
      final output = await picture.toImage(512, 480);
      final bytes = (await output.toByteData())!;
      int pixel(int x, int y) {
        final offset = (y * 512 + x) * 4;
        return 0xff000000 |
            bytes.getUint8(offset) << 16 |
            bytes.getUint8(offset + 1) << 8 |
            bytes.getUint8(offset + 2);
      }

      expect(
        List.generate(256 * 240, (index) {
          final x = index % 256 * 2;
          final y = index ~/ 256 * 2;
          final color = pixel(x, y);
          return (x >= 128 || color == 0xff000000) &&
              color == pixel(x + 1, y) &&
              color == pixel(x, y + 1) &&
              color == pixel(x + 1, y + 1);
        }).every((matches) => matches),
        isTrue,
      );
      output.dispose();
      picture.dispose();
      shader.dispose();
      frame.dispose();
    },
  );
}
