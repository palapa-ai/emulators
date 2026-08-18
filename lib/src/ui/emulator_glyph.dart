import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'emulator_skin.dart';

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
    painter: _GlyphPainter(
      icon: icon,
      color: color ?? const Color(0xffe8e8ee),
    ),
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

    switch (icon) {
      case EmulatorIcon.play:
        canvas.drawPath(
          Path()
            ..moveTo(4.5, 3)
            ..lineTo(13, 8)
            ..lineTo(4.5, 13)
            ..close(),
          fill,
        );
      case EmulatorIcon.pause:
        canvas.drawRRect(_bar(5, 3, 2, 10), fill);
        canvas.drawRRect(_bar(9, 3, 2, 10), fill);
      case EmulatorIcon.reset:
        canvas.drawArc(
          const Rect.fromLTWH(3.2, 3.2, 9.6, 9.6),
          -math.pi / 2,
          math.pi * 1.55,
          false,
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8, 1)
            ..lineTo(8, 5)
            ..lineTo(4.6, 3)
            ..close(),
          fill,
        );
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
      case EmulatorIcon.controller:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(1.5, 4.5, 13, 7),
            const Radius.circular(3),
          ),
          stroke,
        );
        canvas.drawLine(const Offset(4, 8), const Offset(6.4, 8), stroke);
        canvas.drawLine(const Offset(5.2, 6.8), const Offset(5.2, 9.2), stroke);
        canvas.drawCircle(const Offset(11, 7), 0.9, fill);
        canvas.drawCircle(const Offset(11, 9.4), 0.9, fill);
      case EmulatorIcon.display:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(1.8, 3, 12.4, 8.5),
            const Radius.circular(1.6),
          ),
          stroke,
        );
        canvas.drawLine(const Offset(5.5, 14), const Offset(10.5, 14), stroke);
      case EmulatorIcon.sound:
      case EmulatorIcon.muted:
        canvas.drawPath(
          Path()
            ..moveTo(3, 6)
            ..lineTo(5.5, 6)
            ..lineTo(8.5, 3)
            ..lineTo(8.5, 13)
            ..lineTo(5.5, 10)
            ..lineTo(3, 10)
            ..close(),
          fill,
        );
        if (icon == EmulatorIcon.sound) {
          canvas.drawArc(
            const Rect.fromLTWH(8, 4.5, 4, 7),
            -math.pi / 3,
            math.pi * 2 / 3,
            false,
            stroke,
          );
          canvas.drawArc(
            const Rect.fromLTWH(8.5, 2.5, 6.5, 11),
            -math.pi / 3,
            math.pi * 2 / 3,
            false,
            stroke,
          );
        } else {
          canvas.drawLine(const Offset(11, 6), const Offset(14, 10), stroke);
          canvas.drawLine(const Offset(14, 6), const Offset(11, 10), stroke);
        }
      case EmulatorIcon.save:
      case EmulatorIcon.load:
        final down = icon == EmulatorIcon.save;
        canvas.drawPath(
          Path()
            ..moveTo(2.5, 9.5)
            ..lineTo(2.5, 13)
            ..lineTo(13.5, 13)
            ..lineTo(13.5, 9.5),
          stroke,
        );
        canvas.drawLine(
          Offset(8, down ? 2.5 : 9.5),
          Offset(8, down ? 9.5 : 2.5),
          stroke,
        );
        canvas.drawPath(
          down
              ? (Path()
                  ..moveTo(5.4, 7)
                  ..lineTo(8, 9.8)
                  ..lineTo(10.6, 7))
              : (Path()
                  ..moveTo(5.4, 5.2)
                  ..lineTo(8, 2.4)
                  ..lineTo(10.6, 5.2)),
          stroke,
        );
      case EmulatorIcon.speed:
        canvas.drawArc(
          const Rect.fromLTWH(2, 3.5, 12, 12),
          math.pi,
          math.pi,
          false,
          stroke,
        );
        canvas.drawLine(const Offset(8, 9.5), const Offset(11, 6), stroke);
      case EmulatorIcon.delete:
        canvas.drawLine(const Offset(2.5, 4), const Offset(13.5, 4), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(6, 4)
            ..lineTo(6.6, 2.2)
            ..lineTo(9.4, 2.2)
            ..lineTo(10, 4),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(3.8, 4)
            ..lineTo(4.6, 13.6)
            ..lineTo(11.4, 13.6)
            ..lineTo(12.2, 4),
          stroke,
        );
      case EmulatorIcon.copy:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2.2, 2.2, 8, 9.6),
            const Radius.circular(1.4),
          ),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5.8, 4.6, 8, 9.6),
            const Radius.circular(1.4),
          ),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeJoin = StrokeJoin.round,
        );
      case EmulatorIcon.check:
        canvas.drawPath(
          Path()
            ..moveTo(3, 8.4)
            ..lineTo(6.6, 12)
            ..lineTo(13, 4.4),
          stroke..strokeWidth = 1.8,
        );
    }

    canvas.restore();
  }

  RRect _bar(double x, double y, double w, double h) => RRect.fromRectAndRadius(
    Rect.fromLTWH(x, y, w, h),
    const Radius.circular(0.6),
  );

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.icon != icon || old.color != color;
}
