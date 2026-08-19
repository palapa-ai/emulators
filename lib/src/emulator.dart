import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'emulator_button.dart';
import 'libretro_bindings.dart';
import 'native_memory.dart';

class EmulatorException implements Exception {
  EmulatorException(this.message);

  final String message;

  @override
  String toString() => 'EmulatorException: $message';
}

/// One running game: a libretro core with a ROM loaded.
///
/// libretro cores keep their state in globals, so only one [Emulator] can be
/// open at a time in a process; [open] throws while another is alive.
class Emulator {
  Emulator._(
    this._bindings,
    this._session,
    this.corePath,
    this.romPath,
    this._isolated,
  );

  /// Each session dlopens its **own copy** of the core. libretro keeps its
  /// state in globals, and dyld hands back the same image for the same path —
  /// so without a private copy a second session would silently share the
  /// first one's memory.
  static Emulator open({required String corePath, required String romPath}) {
    final bindings = LibretroBindings.open();
    final isolated = _CoreCopies.take(corePath);

    final core = isolated.toNative();
    final rom = romPath.toNative();
    final err = allocate(512).cast<Utf8>();

    try {
      final session = bindings.open(core, rom, err, 512);
      if (session == nullptr) {
        _CoreCopies.discard(isolated);
        throw EmulatorException(err.toDart());
      }
      return Emulator._(bindings, session, corePath, romPath, isolated);
    } finally {
      release(core);
      release(rom);
      release(err);
    }
  }

  final LibretroBindings _bindings;
  final Pointer<EmuSession> _session;
  final String corePath;
  final String romPath;
  final String _isolated;

  bool _closed = false;

  String get coreName => _bindings.coreName(_session).toDart();
  String get coreVersion => _bindings.coreVersion(_session).toDart();
  double get framesPerSecond => _bindings.fps(_session);
  double get sampleRate => _bindings.sampleRate(_session);
  double get aspectRatio => _bindings.aspectRatio(_session);
  int get frameWidth => _bindings.frameWidth(_session);
  int get frameHeight => _bindings.frameHeight(_session);

  void runFrame() => _bindings.runFrame(_session);

  void reset() => _bindings.reset(_session);

  bool startAudio() => _bindings.audioStart(_session) == 0;

  void stopAudio() => _bindings.audioStop(_session);

  int get queuedAudioFrames => _bindings.audioQueued(_session);

  bool get isAudioMuted => _bindings.audioMuted(_session) != 0;

  void setAudioMuted({required bool muted}) =>
      _bindings.audioSetMuted(_session, muted ? 1 : 0);

  void setAudioDiscard({required bool discard}) =>
      _bindings.audioSetDiscard(_session, discard ? 1 : 0);

  void setAudioQuality({required int bits, required bool mono}) =>
      _bindings.audioSetQuality(_session, bits, mono ? 1 : 0);

  void setButton(EmulatorButton button, {required bool pressed}) =>
      _bindings.setButton(_session, button.id, pressed ? 1 : 0);

  /// The last rendered frame as ARGB8888. The returned view aliases native
  /// memory that the next [runFrame] overwrites — copy it to keep it.
  Uint32List? get frame {
    final pixels = _bindings.framePixels(_session);
    final w = frameWidth;
    final h = frameHeight;

    if (pixels == nullptr || w <= 0 || h <= 0) return null;
    return pixels.asTypedList(w * h);
  }

  /// Drains queued audio as interleaved stereo 16-bit frames.
  Int16List readAudio({int maxFrames = 4096}) {
    final buffer = allocate(maxFrames * 2 * sizeOf<Int16>()).cast<Int16>();

    try {
      final got = _bindings.audioRead(_session, buffer, maxFrames);
      return Int16List.fromList(buffer.asTypedList(got * 2));
    } finally {
      release(buffer);
    }
  }

  Uint8List? saveState() {
    final size = _bindings.stateSize(_session);
    if (size == 0) return null;

    final buffer = allocate(size);

    try {
      if (_bindings.stateSave(_session, buffer.cast(), size) == 0) return null;
      return Uint8List.fromList(buffer.asTypedList(size));
    } finally {
      release(buffer);
    }
  }

  bool loadState(Uint8List state) {
    final buffer = allocate(state.length);

    try {
      buffer.asTypedList(state.length).setAll(0, state);
      return _bindings.stateLoad(_session, buffer.cast(), state.length) != 0;
    } finally {
      release(buffer);
    }
  }

  /// Battery-backed cartridge RAM, or null when the game has none.
  Uint8List? get saveRam {
    final size = _bindings.sramSize(_session);
    final data = _bindings.sramData(_session);

    if (size == 0 || data == nullptr) return null;
    return Uint8List.fromList(data.cast<Uint8>().asTypedList(size));
  }

  void writeSaveRam(Uint8List bytes) {
    final size = _bindings.sramSize(_session);
    final data = _bindings.sramData(_session);

    if (size == 0 || data == nullptr) return;

    final take = bytes.length < size ? bytes.length : size;
    data.cast<Uint8>().asTypedList(size).setRange(0, take, bytes);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _bindings.close(_session);
    _CoreCopies.discard(_isolated);
  }
}

/// Hands out a fresh on-disk copy of a core for every [Emulator.open].
///
/// A copy is never reused: `dlclose` is not guaranteed to unload on macOS, so
/// a second `dlopen` of the same path could hand back the first game's dirty
/// globals. Spares are cut in the background instead, because the copy used to
/// happen inline and scrolling the shelf meant megabytes of blocking I/O.
class _CoreCopies {
  static final _root = Directory.systemTemp.createTempSync('emulator_cores');
  static final _ready = <String, List<String>>{};
  static var _next = 0;
  static const _spares = 4;

  static String take(String corePath) {
    final ready = _ready[corePath] ??= <String>[];
    final copy = ready.isEmpty ? _cut(corePath) : ready.removeLast();
    unawaited(_topUp(corePath));
    return copy;
  }

  static void discard(String copy) => unawaited(File(copy).delete());

  static String _cut(String corePath) {
    final copy = '${_root.path}/core${_next++}.dylib';
    File(corePath).copySync(copy);
    return copy;
  }

  static Future<void> _topUp(String corePath) async {
    final ready = _ready[corePath] ??= <String>[];
    while (ready.length < _spares) {
      final copy = '${_root.path}/core${_next++}.dylib';
      await File(corePath).copy(copy);
      ready.add(copy);
    }
  }
}
