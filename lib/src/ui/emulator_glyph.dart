import 'package:flutter/widgets.dart';

import '../display_style.dart';
import '../emulator_session.dart';
import 'emulator_skin.dart';

part 'cupertino_paths.dart';

extension DisplayStyleIcon on DisplayStyle? {
  EmulatorIcon get icon => switch (this) {
    null => EmulatorIcon.styleRaw,
    DisplayStyle.vhs => EmulatorIcon.styleVhs,
    DisplayStyle.trinitron => EmulatorIcon.styleTrinitron,
    DisplayStyle.arcade => EmulatorIcon.styleArcade,
    DisplayStyle.homeTv => EmulatorIcon.styleHomeTv,
    DisplayStyle.dotMatrix => EmulatorIcon.styleDotMatrix,
    DisplayStyle.nes => EmulatorIcon.styleNes,
    DisplayStyle.gameBoy => EmulatorIcon.styleGameBoy,
    DisplayStyle.composite => EmulatorIcon.styleComposite,
  };
}

extension EmulatorSpeedIcon on EmulatorSpeed {
  EmulatorIcon get icon => switch (this) {
    EmulatorSpeed.quarter => EmulatorIcon.speedQuarter,
    EmulatorSpeed.half => EmulatorIcon.speedHalf,
    EmulatorSpeed.normal => EmulatorIcon.speedNormal,
    EmulatorSpeed.fast => EmulatorIcon.speedDouble,
    EmulatorSpeed.turbo => EmulatorIcon.speedQuad,
  };
}

/// Drawn rather than set in a font: an icon font would be a dependency, and
/// these are simple enough to be paths.
class EmulatorGlyph extends StatelessWidget {
  const EmulatorGlyph(this.icon, {super.key, this.size = 14, this.color});

  final EmulatorIcon icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _GlyphPainter(icon: icon, color: color ?? const Color(0xffe8e8ee)),
  );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({required this.icon, required this.color});

  final EmulatorIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 16;
    canvas.save();
    canvas.scale(unit);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // The standard chrome draws with vendored Cupertino outlines; only the
    // icons with no Cupertino equivalent are drawn by hand below.
    final cupertino = _cupertinoPaths[icon];
    if (cupertino != null) {
      canvas.drawPath(cupertino, fill);
      canvas.restore();
      return;
    }

    switch (icon) {
      // Covered by the vendored Cupertino outlines above.
      case EmulatorIcon.play:
      case EmulatorIcon.pause:
      case EmulatorIcon.reset:
      case EmulatorIcon.controller:
      case EmulatorIcon.sound:
      case EmulatorIcon.muted:
      case EmulatorIcon.save:
      case EmulatorIcon.load:
      case EmulatorIcon.delete:
      case EmulatorIcon.copy:
      case EmulatorIcon.check:
      case EmulatorIcon.fullscreen:
        break;
      case EmulatorIcon.eject:
        canvas.drawPath(
          Path()
            ..moveTo(8, 3)
            ..lineTo(13.5, 9.5)
            ..lineTo(2.5, 9.5)
            ..close(),
          fill,
        );
        canvas.drawRRect(_bar(2.5, 11.5, 11, 1.8), fill);
      case EmulatorIcon.styleRaw:
        canvas.drawRRect(_bar(2.5, 4, 11, 8.5), stroke);
      case EmulatorIcon.styleVhs:
        canvas.drawRRect(_bar(2, 4.5, 12, 7.5), stroke);
        canvas.drawCircle(const Offset(5.5, 8.2), 1.5, stroke);
        canvas.drawCircle(const Offset(10.5, 8.2), 1.5, stroke);
      case EmulatorIcon.styleTrinitron:
        canvas.drawRRect(_bar(2.5, 4, 11, 8.5), stroke);
        for (final x in [6.0, 8.0, 10.0]) {
          canvas.drawLine(Offset(x, 5.8), Offset(x, 10.7), stroke);
        }
      case EmulatorIcon.styleArcade:
        canvas.drawLine(const Offset(4, 13), const Offset(12, 13), stroke);
        canvas.drawLine(const Offset(8, 13), const Offset(8, 7.5), stroke);
        canvas.drawCircle(const Offset(8, 5), 2.2, fill);
      case EmulatorIcon.styleHomeTv:
        canvas.drawRRect(_bar(2.5, 6, 11, 7), stroke);
        canvas.drawLine(const Offset(8, 6), const Offset(5, 2.5), stroke);
        canvas.drawLine(const Offset(8, 6), const Offset(11, 2.5), stroke);
      case EmulatorIcon.styleDotMatrix:
        for (var y = 0; y < 3; y++) {
          for (var x = 0; x < 3; x++) {
            canvas.drawCircle(Offset(4.5 + x * 3.5, 4.5 + y * 3.5), 1, fill);
          }
        }
      case EmulatorIcon.styleNes:
        canvas.drawRRect(_bar(2, 5, 12, 6.5), stroke);
        canvas.drawLine(const Offset(5, 6.7), const Offset(5, 9.8), stroke);
        canvas.drawLine(const Offset(3.5, 8.2), const Offset(6.5, 8.2), stroke);
        canvas.drawCircle(const Offset(10, 8.2), 0.9, fill);
        canvas.drawCircle(const Offset(12.2, 8.2), 0.9, fill);
      case EmulatorIcon.styleGameBoy:
        canvas.drawRRect(_bar(4.5, 2, 7, 12), stroke);
        canvas.drawRRect(_bar(6, 3.5, 4, 4), stroke);
        canvas.drawCircle(const Offset(9.5, 10.5), 0.9, fill);
        canvas.drawCircle(const Offset(6.5, 11.5), 0.7, fill);
      case EmulatorIcon.styleComposite:
        for (final (x, y) in [(4.0, 8.0), (8.0, 8.0), (12.0, 8.0)]) {
          canvas.drawCircle(Offset(x, y), 1.7, stroke);
          canvas.drawCircle(Offset(x, y), 0.5, fill);
        }
      case EmulatorIcon.speedQuarter:
        _chevron(canvas, stroke, 9.5, left: true);
        _chevron(canvas, stroke, 5.5, left: true);
      case EmulatorIcon.speedHalf:
        _chevron(canvas, stroke, 7.5, left: true);
      case EmulatorIcon.speedNormal:
        canvas.drawPath(
          Path()
            ..moveTo(5.5, 4)
            ..lineTo(11.5, 8)
            ..lineTo(5.5, 12)
            ..close(),
          stroke,
        );
      case EmulatorIcon.speedDouble:
        _chevron(canvas, stroke, 4.5);
        _chevron(canvas, stroke, 8.5);
      case EmulatorIcon.speedQuad:
        _chevron(canvas, stroke, 3);
        _chevron(canvas, stroke, 6.8);
        _chevron(canvas, stroke, 10.6);
    }

    canvas.restore();
  }

  void _chevron(Canvas canvas, Paint paint, double x, {bool left = false}) {
    final dx = left ? -3.5 : 3.5;
    canvas.drawPath(
      Path()
        ..moveTo(left ? x + 3.5 : x, 4)
        ..lineTo((left ? x + 3.5 : x) + dx, 8)
        ..lineTo(left ? x + 3.5 : x, 12),
      paint,
    );
  }

  RRect _bar(double x, double y, double w, double h) => RRect.fromRectAndRadius(
    Rect.fromLTWH(x, y, w, h),
    const Radius.circular(0.6),
  );

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.icon != icon || old.color != color;
}
