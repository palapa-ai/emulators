import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'emulator.dart';
import 'emulator_button.dart';
import 'gamepad.dart';
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

  /// Discovered after construction when a host did not name one, so the
  /// screen can render before the lookup finishes.
  String? corePath;

  Emulator? _emulator;
  Timer? _pump;
  bool _decoding = false;

  final _gamepad = Gamepad.open();
  int _keyboard = 0;

  bool get hasGamepad => _gamepad.isConnected;

  /// Roughly three frames of sound in hand — enough to ride out a slow decode,
  /// short enough that a button press is not heard late.
  int get _targetBacklogFrames =>
      ((_emulator?.sampleRate ?? 32040) / (_emulator?.framesPerSecond ?? 60) * 3)
          .round();

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

    _emulator?.startAudio();

    // Woken far faster than frame rate; _tick decides whether to actually run
    // one, so the audio device sets the pace instead of this timer.
    _pump = Timer.periodic(
      const Duration(milliseconds: 2),
      (_) => unawaited(_tick()),
    );
    notifyListeners();
  }

  void stop() {
    _keyboard = 0;
    _pump?.cancel();
    _pump = null;
    _emulator?.stopAudio();
    _emulator?.close();
    _emulator = null;
    _rom = null;
    _frame = null;
    if (_status == SessionStatus.running) _status = SessionStatus.idle;
    notifyListeners();
  }

  void reset() => _emulator?.reset();

  /// Held keys are remembered rather than pushed straight through, because
  /// the pad is polled every frame and would otherwise clear them.
  void press(EmulatorButton button, {required bool pressed}) {
    final bit = 1 << button.id;
    _keyboard = pressed ? _keyboard | bit : _keyboard & ~bit;
  }

  void _applyInput() {
    final held = _keyboard | _gamepad.pressed;

    for (final button in EmulatorButton.values) {
      _emulator?.setButton(button, pressed: held >> button.id & 1 == 1);
    }
  }

  /// Runs only while the sound card is short of work. Pacing on the backlog
  /// rather than a wall clock means the emulator cannot drift against the
  /// device, which is what makes audio crackle or slowly desynchronise.
  Future<void> _tick() async {
    final emulator = _emulator;
    if (emulator == null || _decoding) return;
    if (emulator.queuedAudioFrames >= _targetBacklogFrames) return;

    _decoding = true;
    try {
      _applyInput();
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
