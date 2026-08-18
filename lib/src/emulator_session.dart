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
  final _log = <String>[];
  final _buttonLog = <EmulatorButton>[];
  int _lastHeld = 0;

  /// Newest last. Only presses land here, not releases or repeats.
  List<EmulatorButton> get buttonLog => List.unmodifiable(_buttonLog);

  List<String> get logLines => List.unmodifiable(_log);

  void log(String line) {
    final now = DateTime.now();
    final stamp =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    _log.add('$stamp  $line');
    if (_log.length > 200) _log.removeAt(0);
    notifyListeners();
  }

  int _keyboard = 0;

  bool get hasGamepad => _gamepad.isConnected;
  String? get gamepadName => _gamepad.name;

  /// Roughly three frames of sound in hand — enough to ride out a slow decode,
  /// short enough that a button press is not heard late.
  int get _targetBacklogFrames =>
      ((_emulator?.sampleRate ?? 32040) / (_emulator?.framesPerSecond ?? 60) * 3)
          .round();

  SessionStatus _status = SessionStatus.idle;
  bool _paused = false;
  RomFile? _rom;
  ui.Image? _frame;
  String? _error;

  SessionStatus get status => _status;
  RomFile? get rom => _rom;
  ui.Image? get frame => _frame;
  String? get error => _error;
  bool get isRunning => _emulator != null;
  bool get isPaused => _paused;
  double get aspectRatio => _emulator?.aspectRatio ?? 4 / 3;
  String get coreName => _emulator?.coreName ?? '';

  void play(RomFile rom) {
    stop();

    final core = corePath;
    if (core == null) {
      _status = SessionStatus.unavailable;
      _error = 'No emulator core is bundled for this platform.';
      log('no core available');
      notifyListeners();
      return;
    }

    try {
      _emulator = Emulator.open(corePath: core, romPath: rom.path);
      _status = SessionStatus.running;
      _rom = rom;
      _error = null;
      _paused = false;
      log('loaded ${rom.title}');
      log('core ${_emulator?.coreName} ${_emulator?.coreVersion}');
    } on Object catch (e) {
      _emulator = null;
      _status = SessionStatus.failed;
      _error = '$e';
      log('failed to load ${rom.title}');
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
    _lastHeld = 0;
    _buttonLog.clear();
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

  void pause() {
    if (_emulator == null || _paused) return;
    _paused = true;
    _emulator?.stopAudio();
    log('paused');
    notifyListeners();
  }

  void resume() {
    if (_emulator == null || !_paused) return;
    _paused = false;
    _emulator?.startAudio();
    log('resumed');
    notifyListeners();
  }

  void reset() {
    _emulator?.reset();
    log('reset');
  }

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

    final pressed = held & ~_lastHeld;
    _lastHeld = held;
    if (pressed == 0) return;

    _buttonLog.addAll(
      EmulatorButton.values.where((b) => pressed >> b.id & 1 == 1),
    );
    if (_buttonLog.length > 120) {
      _buttonLog.removeRange(0, _buttonLog.length - 120);
    }
    notifyListeners();
  }

  /// Runs only while the sound card is short of work. Pacing on the backlog
  /// rather than a wall clock means the emulator cannot drift against the
  /// device, which is what makes audio crackle or slowly desynchronise.
  Future<void> _tick() async {
    final emulator = _emulator;
    if (emulator == null || _decoding || _paused) return;
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
