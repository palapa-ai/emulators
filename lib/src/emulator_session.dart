import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'emulator.dart';
import 'emulator_button.dart';
import 'rom_file.dart';

/// [unavailable] is not something the user did — it means no native core was
/// bundled for this platform, which a host still has to be able to render.
enum SessionStatus { idle, running, unavailable, failed }

/// A running game, driven a frame at a time and published as decoded images.
///
/// libretro cores hold their state in globals, so one session exists at a
/// time — [play] closes the previous one before opening another.
class EmulatorSession extends ChangeNotifier {
  EmulatorSession({this.corePath});

  final String? corePath;

  Emulator? _emulator;
  Timer? _pump;
  bool _decoding = false;

  SessionStatus _status = SessionStatus.idle;
  RomFile? _rom;
  ui.Image? _frame;
  String? _error;

  SessionStatus get status => _status;
  RomFile? get rom => _rom;
  ui.Image? get frame => _frame;
  String? get error => _error;
  bool get isRunning => _emulator != null;
  double get aspectRatio => _emulator?.aspectRatio ?? 4 / 3;
  String get coreName => _emulator?.coreName ?? '';

  void play(RomFile rom) {
    stop();

    final core = corePath;
    if (core == null) {
      _status = SessionStatus.unavailable;
      _error = 'No emulator core is bundled for this platform.';
      notifyListeners();
      return;
    }

    try {
      _emulator = Emulator.open(corePath: core, romPath: rom.path);
      _status = SessionStatus.running;
      _rom = rom;
      _error = null;
    } on Object catch (e) {
      _emulator = null;
      _status = SessionStatus.failed;
      _error = '$e';
      notifyListeners();
      return;
    }

    final fps = _emulator?.framesPerSecond ?? 60;
    _pump = Timer.periodic(
      Duration(microseconds: (1000000 / fps).round()),
      (_) => unawaited(_tick()),
    );
    notifyListeners();
  }

  void stop() {
    _pump?.cancel();
    _pump = null;
    _emulator?.close();
    _emulator = null;
    _rom = null;
    _frame = null;
    if (_status == SessionStatus.running) _status = SessionStatus.idle;
    notifyListeners();
  }

  void reset() => _emulator?.reset();

  void press(EmulatorButton button, {required bool pressed}) =>
      _emulator?.setButton(button, pressed: pressed);

  /// Decoding off the timer means a slow frame is dropped rather than queued
  /// behind work the core has already moved past.
  Future<void> _tick() async {
    final emulator = _emulator;
    if (emulator == null || _decoding) return;

    _decoding = true;
    try {
      emulator.runFrame();

      final pixels = emulator.frame;
      final width = emulator.frameWidth;
      final height = emulator.frameHeight;
      if (pixels == null || width <= 0 || height <= 0) return;

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels.buffer.asUint8List(0, width * height * 4),
        width,
        height,
        ui.PixelFormat.bgra8888,
        completer.complete,
      );

      _frame = await completer.future;
      notifyListeners();
    } finally {
      _decoding = false;
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
