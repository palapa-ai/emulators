import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../display_style.dart';

/// Runs the parameterised style shader over a frame.
///
/// The geometric overlay can darken a grid, but it cannot recolour what the
/// game drew — composite fringing and the DMG's four greens read the picture,
/// so every style is painted per-pixel here.
class StyleShaderView extends StatefulWidget {
  const StyleShaderView({required this.frame, required this.style, super.key});

  final ui.Image frame;
  final DisplayStyle style;

  @override
  State<StyleShaderView> createState() => _StyleShaderViewState();
}

class _StyleShaderViewState extends State<StyleShaderView>
    with SingleTickerProviderStateMixin {
  static Future<ui.FragmentProgram>? _program;

  ui.FragmentShader? _shader;
  Ticker? _ticker;
  double _seconds = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    // Only composite video moves on its own — the crawl needs a clock.
    if (widget.style.shaderMode == 1) {
      _ticker = Ticker((elapsed) {
        setState(() => _seconds = elapsed.inMicroseconds / 1000000);
      })..start();
    }
  }

  Future<void> _load() async {
    _program ??= ui.FragmentProgram.fromAsset(
      'packages/emulators/shaders/crt.frag',
    );
    final program = await _program;
    if (mounted && program != null) {
      setState(() => _shader = program.fragmentShader());
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) {
      return RawImage(image: widget.frame, fit: BoxFit.contain);
    }

    return CustomPaint(
      painter: _StylePainter(shader, widget.frame, widget.style, _seconds),
      child: const SizedBox.expand(),
    );
  }
}

class _StylePainter extends CustomPainter {
  _StylePainter(this.shader, this.frame, this.style, this.seconds);

  final ui.FragmentShader shader;
  final ui.Image frame;
  final DisplayStyle style;
  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, seconds)
      ..setFloat(3, frame.width.toDouble())
      ..setFloat(4, frame.height.toDouble())
      ..setFloat(5, style.nativeWidth.toDouble())
      ..setFloat(6, style.nativeHeight.toDouble())
      ..setFloat(7, style.scanline)
      ..setFloat(8, style.scanlineDepth)
      ..setFloat(9, style.verticalStripe)
      ..setFloat(10, style.verticalStripeDepth)
      ..setFloat(11, style.pixelGap)
      ..setFloat(12, style.pixelGapDepth)
      ..setFloat(13, style.phosphor ? 1 : 0)
      ..setFloat(14, style.phosphorDepth)
      ..setFloat(15, style.tint.r)
      ..setFloat(16, style.tint.g)
      ..setFloat(17, style.tint.b)
      ..setFloat(18, style.shaderMode)
      ..setImageSampler(0, frame);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_StylePainter old) =>
      old.seconds != seconds || old.frame != frame || old.style != style;
}
