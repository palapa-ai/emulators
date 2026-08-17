import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'emulator_button.dart';
import 'libretro_bindings.dart';

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
  Emulator._(this._bindings, this._session, this.corePath, this.romPath);

  static Emulator open({required String corePath, required String romPath}) {
    final bindings = LibretroBindings.open();
    final core = corePath.toNativeUtf8();
    final rom = romPath.toNativeUtf8();
    final err = calloc<Uint8>(512).cast<Utf8>();

    try {
      final session = bindings.open(core, rom, err, 512);
      if (session == nullptr) {
        throw EmulatorException(err.toDartString());
      }
      return Emulator._(bindings, session, corePath, romPath);
    } finally {
      calloc.free(core);
      calloc.free(rom);
      calloc.free(err);
    }
  }

  final LibretroBindings _bindings;
  final Pointer<EmuSession> _session;
  final String corePath;
  final String romPath;

  bool _closed = false;

  String get coreName => _bindings.coreName(_session).toDartString();
  String get coreVersion => _bindings.coreVersion(_session).toDartString();
  double get framesPerSecond => _bindings.fps(_session);
  double get sampleRate => _bindings.sampleRate(_session);
  double get aspectRatio => _bindings.aspectRatio(_session);
  int get frameWidth => _bindings.frameWidth(_session);
  int get frameHeight => _bindings.frameHeight(_session);

  void runFrame() => _bindings.runFrame(_session);

  void reset() => _bindings.reset(_session);

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
    final buffer = calloc<Int16>(maxFrames * 2);

    try {
      final got = _bindings.audioRead(_session, buffer, maxFrames);
      return Int16List.fromList(buffer.asTypedList(got * 2));
    } finally {
      calloc.free(buffer);
    }
  }

  Uint8List? saveState() {
    final size = _bindings.stateSize(_session);
    if (size == 0) return null;

    final buffer = calloc<Uint8>(size);

    try {
      if (_bindings.stateSave(_session, buffer.cast(), size) == 0) return null;
      return Uint8List.fromList(buffer.asTypedList(size));
    } finally {
      calloc.free(buffer);
    }
  }

  bool loadState(Uint8List state) {
    final buffer = calloc<Uint8>(state.length);

    try {
      buffer.asTypedList(state.length).setAll(0, state);
      return _bindings.stateLoad(_session, buffer.cast(), state.length) != 0;
    } finally {
      calloc.free(buffer);
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
  }
}
