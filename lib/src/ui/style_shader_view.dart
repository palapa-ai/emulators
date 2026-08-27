import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../display_style.dart';

/// Runs a style's fragment shader over a frame.
///
/// The geometric overlay could darken a grid, but it could not recolour what
/// the game drew — tape wobble, composite fringing and the DMG's four greens
/// all read the picture, so every style is painted per-pixel here. VHS has a
/// shader of its own; the rest share the parameterised pass.
class StyleShaderView extends StatefulWidget {
  const StyleShaderView({required this.frame, required this.style, super.key});

  final ui.Image frame;
  final DisplayStyle style;

  @override
  State<StyleShaderView> createState() => _StyleShaderViewState();
}

class _StyleShaderViewState extends State<StyleShaderView>
    with SingleTickerProviderStateMixin {
  // Compiled once for the process — a style switch must not reload an asset.
  static final _programs = <String, Future<ui.FragmentProgram>>{};

  ui.FragmentShader? _shader;
  String? _shaderAsset;
  Ticker? _ticker;
  double _seconds = 0;

  String get _asset => widget.style.shader
      ? 'packages/agentic_emulator/shaders/vhs.frag'
      : 'packages/agentic_emulator/shaders/crt.frag';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _syncTicker();
  }

  // The element outlives style cycling, so the clock and the compiled shader
  // both have to follow the style rather than the mount: without this,
  // leaving composite leaves a per-vsync repaint running on a still picture,
  // and arriving at it never starts the crawl.
  @override
  void didUpdateWidget(StyleShaderView old) {
    super.didUpdateWidget(old);
    if (old.style != widget.style) {
      _syncTicker();
      if (old.style.shader != widget.style.shader) unawaited(_load());
    }
  }

  // Tape and composite video move on their own — those looks need a clock.
  void _syncTicker() {
    if (widget.style.shader || widget.style.shaderMode == 1) {
      _ticker ??= Ticker((elapsed) {
        setState(() => _seconds = elapsed.inMicroseconds / 1000000);
      })..start();
    } else {
      _ticker?.dispose();
      _ticker = null;
      _seconds = 0;
    }
  }

  Future<void> _load() async {
    final asset = _asset;
    final program = await (_programs[asset] ??= ui.FragmentProgram.fromAsset(
      asset,
    ));
    if (!mounted || _shaderAsset == asset) return;
    _shader?.dispose();
    setState(() {
      _shader = program.fragmentShader();
      _shaderAsset = asset;
    });
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
    if (shader == null || _shaderAsset != _asset) {
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
      ..setFloat(4, frame.height.toDouble());

    if (!style.shader) {
      shader
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
        ..setFloat(18, style.shaderMode);
    }
    shader.setImageSampler(0, frame);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_StylePainter old) =>
      old.seconds != seconds || old.frame != frame || old.style != style;
}
