import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'emulator.dart';
import 'emulator_button.dart';
import 'gamepad.dart';
import 'pad_element.dart';
import 'rom_file.dart';

/// [unavailable] is not something the user did — it means no native core was
/// bundled for this platform, which a host still has to be able to render.
enum SessionStatus { idle, running, unavailable, failed }

enum EmulatorSpeed {
  half(0.5, '1/2'),
  normal(1, '1x'),
  fast(2, '2x'),
  turbo(4, '4x');

  const EmulatorSpeed(this.rate, this.label);

  final double rate;
  final String label;
}

/// A running game, driven a frame at a time and published as decoded images.
///
/// libretro cores hold their state in globals, so one session exists at a
/// time — [play] closes the previous one before opening another.
class EmulatorSession extends ChangeNotifier {
  EmulatorSession({this.corePath, this.preview = false});

  /// A preview runs far below full rate and never makes a sound: eight of
  /// these at 60fps would spend the whole machine on pictures nobody is
  /// looking at closely.
  final bool preview;

  static const previewFps = 60;

  /// Discovered after construction when a host did not name one, so the
  /// screen can render before the lookup finishes.
  String? corePath;

  Emulator? _emulator;
  Timer? _pump;
  Timer? _stagger;
  static var _started = 0;
  Timer? _input;
  bool _decoding = false;

  final _gamepad = Gamepad.open();
  final _log = <String>[];
  final _buttonLog = <EmulatorButton>[];
  final _padLog = <PadElement>[];
  int _lastHeld = 0;
  int _lastRaw = 0;
  bool _collecting = true;

  /// Recording can be turned off — it is a diagnostic, not something to run
  /// while someone is just playing.
  bool get isCollecting => _collecting;

  void toggleCollecting() {
    _collecting = !_collecting;
    log(_collecting ? 'input capture on' : 'input capture off');
    notifyListeners();
  }

  List<PadElement> get padLog => List.unmodifiable(_padLog);

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

  /// Six frames of sound in hand. Three left no slack — a single slow frame
  /// decode starved the device and the sound dropped out.
  int get _targetBacklogFrames =>
      ((_emulator?.sampleRate ?? 32040) / (_emulator?.framesPerSecond ?? 60) * 6)
          .round();

  SessionStatus _status = SessionStatus.idle;
  bool _paused = false;
  EmulatorSpeed _speed = EmulatorSpeed.normal;
  final _clock = Stopwatch();
  RomFile? _rom;
  /// Frames are published apart from the rest of the state: a new picture
  /// arrives 60 times a second, and everything watching this session for a
  /// status change has no business rebuilding at that rate.
  final frames = ValueNotifier<ui.Image?>(null);
  ui.Image? _stale;
  String? _error;

  SessionStatus get status => _status;
  RomFile? get rom => _rom;
  ui.Image? get frame => frames.value;
  String? get error => _error;

  bool get isRunning => _emulator != null;
  bool get isPaused => _paused;
  EmulatorSpeed get speed => _speed;

  /// Off 1x wall time takes over as the clock, since the audio device drains
  /// at one rate only. The sound is kept on at every speed regardless, so it
  /// plays back at the pitch the core hands over.
  void cycleSpeed() {
    final next =
        EmulatorSpeed.values[(_speed.index + 1) % EmulatorSpeed.values.length];
    _speed = next;
    _emulator?.setAudioDiscard(discard: false);
    _emulator?.setAudioMuted(muted: false);
    _clock
      ..reset()
      ..start();
    log('${next.label} speed');
    notifyListeners();
  }
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
      if (preview) {
        _emulator?.setAudioDiscard(discard: true);
        _emulator?.setAudioMuted(muted: true);
        _clock
          ..reset()
          ..start();
      }
      _status = SessionStatus.running;
      _rom = rom;
      _error = null;
      _paused = false;
      log('loaded ${rom.title} (${rom.path})');
      log('core ${_emulator?.coreName} ${_emulator?.coreVersion}');
    } on Object catch (e) {
      _emulator = null;
      _status = SessionStatus.failed;
      _error = '$e';
      log('failed to load ${rom.title}');
      notifyListeners();
      return;
    }

    if (!preview) _emulator?.startAudio();

    // Woken far faster than frame rate; _tick decides whether to actually run
    // one, so the audio device sets the pace instead of this timer.
    if (preview) {
      // Started together, every preview would land its frame on the same
      // millisecond and the shelf would beat against the game. Spreading the
      // first tick across the interval keeps the cost flat.
      const interval = 1000 ~/ previewFps;
      _stagger = Timer(
        Duration(milliseconds: (_started++ * 7) % interval),
        () => _pump = Timer.periodic(
          const Duration(milliseconds: interval),
          (_) => unawaited(_tick()),
        ),
      );
    } else {
      _pump = Timer.periodic(
        const Duration(milliseconds: 2),
        (_) => unawaited(_tick()),
      );
    }
    // Nothing plays a preview, so it never reads the pad — polling one per
    // shelf card was the bulk of the input cost.
    if (!preview) {
      _input ??= Timer.periodic(
        const Duration(milliseconds: 8),
        (_) => _applyInput(),
      );
    }
    notifyListeners();
  }

  void stop() {
    _input?.cancel();
    _input = null;
    _keyboard = 0;
    _lastHeld = 0;
    _lastRaw = 0;
    _buttonLog.clear();
    _padLog.clear();
    _stagger?.cancel();
    _stagger = null;
    _pump?.cancel();
    _pump = null;
    _emulator?.stopAudio();
    _emulator?.close();
    _emulator = null;
    _rom = null;
    frames.value = null;
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

  bool get isMuted => _emulator?.isAudioMuted ?? false;

  void setMuted({required bool muted}) {
    if (_emulator?.isAudioMuted == muted) return;
    _emulator?.setAudioMuted(muted: muted);
    notifyListeners();
  }

  void toggleMuted() {
    final emulator = _emulator;
    if (emulator == null) return;
    emulator.setAudioMuted(muted: !emulator.isAudioMuted);
    log(emulator.isAudioMuted ? 'audio muted' : 'audio on');
    notifyListeners();
  }

  /// Naming the slot is the caller's job, so success is logged there.
  Uint8List? saveState() {
    final state = _emulator?.saveState();
    if (state == null) log('save failed');
    return state;
  }

  bool loadState(Uint8List state) {
    final ok = _emulator?.loadState(state) ?? false;
    if (!ok) log('load failed');
    return ok;
  }

  void setAudioQuality({required int bits, required bool mono}) =>
      _emulator?.setAudioQuality(bits: bits, mono: mono);

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

  int _held = 0;

  int get heldMask => _held;
  int get padMask => _gamepad.pressed;
  String? get padName => _gamepad.name;
  int get keyboardMask => _keyboard;

  void _applyInput() {
    final held = _keyboard | _gamepad.pressed;
    final changed = held != _held;
    _held = held;

    for (final button in EmulatorButton.values) {
      _emulator?.setButton(button, pressed: held >> button.id & 1 == 1);
    }

    if (changed) notifyListeners();

    if (!_collecting) return;

    final raw = _gamepad.rawPressed;
    final rawPressed = raw & ~_lastRaw;
    _lastRaw = raw;

    if (rawPressed != 0) {
      _padLog.addAll(
        PadElement.values.where((e) => rawPressed >> e.index & 1 == 1),
      );
      if (_padLog.length > 120) {
        _padLog.removeRange(0, _padLog.length - 120);
      }
    }

    final pressed = held & ~_lastHeld;
    _lastHeld = held;

    if (pressed != 0) {
      _buttonLog.addAll(
        EmulatorButton.values.where((b) => pressed >> b.id & 1 == 1),
      );
      if (_buttonLog.length > 120) {
        _buttonLog.removeRange(0, _buttonLog.length - 120);
      }
    }

    if (pressed != 0 || rawPressed != 0) notifyListeners();
  }

  /// Runs only while the sound card is short of work. Pacing on the backlog
  /// rather than a wall clock means the emulator cannot drift against the
  /// device, which is what makes audio crackle or slowly desynchronise.
  Future<void> _tick() async {
    final emulator = _emulator;
    if (emulator == null || _decoding || _paused) return;

    if (preview) {
      // Paced by the pump itself.
    } else if (_speed == EmulatorSpeed.normal) {
      if (emulator.queuedAudioFrames >= _targetBacklogFrames) return;
    } else {
      final due = 1000 / (emulator.framesPerSecond * _speed.rate);
      if (_clock.elapsedMilliseconds < due) return;
      _clock
        ..reset()
        ..start();
    }

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
        targetWidth: preview ? width ~/ 2 : null,
        targetHeight: preview ? height ~/ 2 : null,
      );

      final stale = _stale;
      _stale = frames.value;
      frames.value = await completer.future;
      stale?.dispose();
    } finally {
      _decoding = false;
    }
  }

  @override
  void dispose() {
    stop();
    frames.dispose();
    super.dispose();
  }
}
