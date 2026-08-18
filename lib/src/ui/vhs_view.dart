import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Runs the VHS fragment shader over a frame.
///
/// Wobble, chroma bleed and head-switching noise are per-pixel and moving —
/// the geometric overlay can draw a grid but not a picture that drifts, so
/// this look needs a real shader.
class VhsView extends StatefulWidget {
  const VhsView({required this.frame, super.key});

  final ui.Image frame;

  @override
  State<VhsView> createState() => _VhsViewState();
}

class _VhsViewState extends State<VhsView> with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  Ticker? _ticker;
  double _seconds = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _ticker = Ticker((elapsed) {
      setState(() => _seconds = elapsed.inMicroseconds / 1000000);
    })..start();
  }

  Future<void> _load() async {
    final program = await ui.FragmentProgram.fromAsset(
      'packages/emulators/shaders/vhs.frag',
    );
    if (mounted) setState(() => _shader = program.fragmentShader());
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
      painter: _VhsPainter(shader, widget.frame, _seconds),
      child: const SizedBox.expand(),
    );
  }
}

class _VhsPainter extends CustomPainter {
  _VhsPainter(this.shader, this.frame, this.seconds);

  final ui.FragmentShader shader;
  final ui.Image frame;
  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, seconds)
      ..setImageSampler(0, frame);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_VhsPainter old) =>
      old.seconds != seconds || old.frame != frame;
}
