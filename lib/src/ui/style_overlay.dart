import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../display_style.dart';

/// Paints a [DisplayStyle] over the picture.
///
/// The geometry is derived from the emulated pixel grid, not the widget size,
/// so scanlines grow with the image instead of getting finer as it scales.
class StyleOverlay extends StatelessWidget {
  const StyleOverlay({
    required this.style,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.child,
    super.key,
  });

  final DisplayStyle? style;
  final int sourceWidth;
  final int sourceHeight;
  final Widget child;

  /// Whichever axis reduces more decides the scale, so one of them lands
  /// exactly on the console's resolution and the picture keeps its shape.
  double get _shrink {
    final s = style;
    if (s == null || s.nativeWidth <= 0 || s.nativeHeight <= 0) return 1;
    return (s.nativeWidth / sourceWidth) < (s.nativeHeight / sourceHeight)
        ? s.nativeWidth / sourceWidth
        : s.nativeHeight / sourceHeight;
  }

  @override
  Widget build(BuildContext context) {
    final style = this.style;
    if (style == null || sourceWidth <= 0 || sourceHeight <= 0) return child;
    if (style.shader) return child;

    final native = style.nativeWidth > 0 && style.nativeHeight > 0
        ? ImageFiltered(
            imageFilter: ImageFilter.compose(
              // Down then up with nearest sampling: the detail is genuinely
              // gone, which is what the smaller console actually looked like.
              outer: ImageFilter.matrix(
                (Matrix4.identity()..scaleByDouble(1 / _shrink, 1 / _shrink, 1, 1))
                    .storage,
                filterQuality: FilterQuality.none,
              ),
              inner: ImageFilter.matrix(
                (Matrix4.identity()..scaleByDouble(_shrink, _shrink, 1, 1))
                    .storage,
                filterQuality: FilterQuality.none,
              ),
            ),
            child: child,
          )
        : child;

    return CustomPaint(
      foregroundPainter: _StylePainter(style, sourceWidth, sourceHeight),
      child: native,
    );
  }
}

class _StylePainter extends CustomPainter {
  _StylePainter(this.style, this.sourceWidth, this.sourceHeight);

  final DisplayStyle style;
  final int sourceWidth;
  final int sourceHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleY = size.height / sourceHeight;
    final scaleX = size.width / sourceWidth;

    if (style.scanline > 0) {
      final paint = Paint()
        ..color = Color.fromRGBO(0, 0, 0, 1 - style.scanlineDepth);
      final band = scaleY * style.scanline;

      for (var y = 0.0; y < size.height; y += scaleY) {
        canvas.drawRect(
          Rect.fromLTWH(0, y + scaleY - band, size.width, band),
          paint,
        );
      }
    }

    if (style.verticalStripe > 0) {
      final paint = Paint()
        ..color = Color.fromRGBO(0, 0, 0, 1 - style.verticalStripeDepth);
      final band = scaleX * style.verticalStripe;

      for (var x = 0.0; x < size.width; x += scaleX) {
        canvas.drawRect(
          Rect.fromLTWH(x + scaleX - band, 0, band, size.height),
          paint,
        );
      }
    }

    if (style.pixelGap > 0) {
      final paint = Paint()
        ..color = Color.fromRGBO(0, 0, 0, 1 - style.pixelGapDepth);
      final gapY = scaleY * style.pixelGap;
      final gapX = scaleX * style.pixelGap;

      for (var y = 0.0; y < size.height; y += scaleY) {
        canvas.drawRect(
          Rect.fromLTWH(0, y + scaleY - gapY, size.width, gapY),
          paint,
        );
      }
      for (var x = 0.0; x < size.width; x += scaleX) {
        canvas.drawRect(
          Rect.fromLTWH(x + scaleX - gapX, 0, gapX, size.height),
          paint,
        );
      }
    }

    if (style.phosphor) {
      final third = scaleX / 3;
      final alpha = 1 - style.phosphorDepth;
      final colors = [
        Color.fromRGBO(255, 0, 0, alpha),
        Color.fromRGBO(0, 255, 0, alpha),
        Color.fromRGBO(0, 0, 255, alpha),
      ];

      for (var x = 0.0; x < size.width; x += scaleX) {
        for (var band = 0; band < 3; band++) {
          canvas.drawRect(
            Rect.fromLTWH(x + third * band, 0, third, size.height),
            Paint()
              ..color = colors[band]
              ..blendMode = BlendMode.screen,
          );
        }
      }
    }

    if (style.tint != const Color(0xffffffff)) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = style.tint
          ..blendMode = BlendMode.modulate,
      );
    }
  }

  @override
  bool shouldRepaint(_StylePainter old) =>
      old.style != style ||
      old.sourceWidth != sourceWidth ||
      old.sourceHeight != sourceHeight;
}
