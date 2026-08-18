import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

final class EmuSession extends Opaque {}

typedef _OpenNative =
    Pointer<EmuSession> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Size,
    );
typedef EmuOpen =
    Pointer<EmuSession> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
    );

typedef _VoidSessionNative = Void Function(Pointer<EmuSession>);
typedef EmuVoidSession = void Function(Pointer<EmuSession>);

typedef _IntSessionNative = Int Function(Pointer<EmuSession>);
typedef EmuIntSession = int Function(Pointer<EmuSession>);

typedef _SizeSessionNative = Size Function(Pointer<EmuSession>);
typedef EmuSizeSession = int Function(Pointer<EmuSession>);

typedef _DoubleSessionNative = Double Function(Pointer<EmuSession>);
typedef EmuDoubleSession = double Function(Pointer<EmuSession>);

typedef _StringSessionNative = Pointer<Utf8> Function(Pointer<EmuSession>);
typedef EmuStringSession = Pointer<Utf8> Function(Pointer<EmuSession>);

typedef _PixelsNative = Pointer<Uint32> Function(Pointer<EmuSession>);
typedef EmuPixels = Pointer<Uint32> Function(Pointer<EmuSession>);

typedef _AudioReadNative =
    Int Function(Pointer<EmuSession>, Pointer<Int16>, Int);
typedef EmuAudioRead = int Function(Pointer<EmuSession>, Pointer<Int16>, int);

typedef _SetButtonNative = Void Function(Pointer<EmuSession>, Int, Int);
typedef EmuSetButton = void Function(Pointer<EmuSession>, int, int);

typedef _StateIoNative = Int Function(Pointer<EmuSession>, Pointer<Void>, Size);
typedef EmuStateIo = int Function(Pointer<EmuSession>, Pointer<Void>, int);

typedef _SramDataNative = Pointer<Void> Function(Pointer<EmuSession>);
typedef EmuSramData = Pointer<Void> Function(Pointer<EmuSession>);

typedef _IntFromSessionNative = Int Function(Pointer<EmuSession>);
typedef EmuIntFromSession = int Function(Pointer<EmuSession>);
typedef _SetMutedNative = Void Function(Pointer<EmuSession>, Int);
typedef EmuSetMuted = void Function(Pointer<EmuSession>, int);

/// Thin `dart:ffi` surface over `src/libretro_host.c`. Holds no policy — the
/// decisions live in [Emulator].
class LibretroBindings {
  LibretroBindings._(DynamicLibrary lib)
    : open = lib.lookupFunction<_OpenNative, EmuOpen>('emu_open'),
      close = lib.lookupFunction<_VoidSessionNative, EmuVoidSession>(
        'emu_close',
      ),
      runFrame = lib.lookupFunction<_VoidSessionNative, EmuVoidSession>(
        'emu_run_frame',
      ),
      reset = lib.lookupFunction<_VoidSessionNative, EmuVoidSession>(
        'emu_reset',
      ),
      framePixels = lib.lookupFunction<_PixelsNative, EmuPixels>(
        'emu_frame_pixels',
      ),
      frameWidth = lib.lookupFunction<_IntSessionNative, EmuIntSession>(
        'emu_frame_width',
      ),
      frameHeight = lib.lookupFunction<_IntSessionNative, EmuIntSession>(
        'emu_frame_height',
      ),
      audioRead = lib.lookupFunction<_AudioReadNative, EmuAudioRead>(
        'emu_audio_read',
      ),
      setButton = lib.lookupFunction<_SetButtonNative, EmuSetButton>(
        'emu_set_button',
      ),
      fps = lib.lookupFunction<_DoubleSessionNative, EmuDoubleSession>(
        'emu_fps',
      ),
      sampleRate = lib.lookupFunction<_DoubleSessionNative, EmuDoubleSession>(
        'emu_sample_rate',
      ),
      aspectRatio = lib.lookupFunction<_DoubleSessionNative, EmuDoubleSession>(
        'emu_aspect_ratio',
      ),
      coreName = lib.lookupFunction<_StringSessionNative, EmuStringSession>(
        'emu_core_name',
      ),
      coreVersion = lib.lookupFunction<_StringSessionNative, EmuStringSession>(
        'emu_core_version',
      ),
      stateSize = lib.lookupFunction<_SizeSessionNative, EmuSizeSession>(
        'emu_state_size',
      ),
      stateSave = lib.lookupFunction<_StateIoNative, EmuStateIo>(
        'emu_state_save',
      ),
      stateLoad = lib.lookupFunction<_StateIoNative, EmuStateIo>(
        'emu_state_load',
      ),
      sramSize = lib.lookupFunction<_SizeSessionNative, EmuSizeSession>(
        'emu_sram_size',
      ),
      sramData = lib.lookupFunction<_SramDataNative, EmuSramData>(
        'emu_sram_data',
      ),
      audioStart = lib.lookupFunction<_IntFromSessionNative, EmuIntFromSession>(
        'emu_audio_start',
      ),
      audioStop = lib.lookupFunction<_VoidSessionNative, EmuVoidSession>(
        'emu_audio_stop',
      ),
      audioQueued = lib
          .lookupFunction<_IntFromSessionNative, EmuIntFromSession>(
            'emu_audio_queued',
          ),
      audioSetMuted = lib.lookupFunction<_SetMutedNative, EmuSetMuted>(
        'emu_audio_set_muted',
      ),
      audioMuted = lib
          .lookupFunction<_IntFromSessionNative, EmuIntFromSession>(
            'emu_audio_muted',
          );

  /// Apple builds link the plugin statically into the app binary, so the
  /// symbols are already in the process and there is no library to open.
  factory LibretroBindings.open() => LibretroBindings._(
    Platform.isMacOS || Platform.isIOS
        ? DynamicLibrary.process()
        : DynamicLibrary.open(Platform.isWindows
              ? 'emulators.dll'
              : 'libemulators.so'),
  );

  final EmuOpen open;
  final EmuVoidSession close;
  final EmuVoidSession runFrame;
  final EmuVoidSession reset;
  final EmuPixels framePixels;
  final EmuIntSession frameWidth;
  final EmuIntSession frameHeight;
  final EmuAudioRead audioRead;
  final EmuSetButton setButton;
  final EmuDoubleSession fps;
  final EmuDoubleSession sampleRate;
  final EmuDoubleSession aspectRatio;
  final EmuStringSession coreName;
  final EmuStringSession coreVersion;
  final EmuSizeSession stateSize;
  final EmuStateIo stateSave;
  final EmuStateIo stateLoad;
  final EmuSizeSession sramSize;
  final EmuSramData sramData;
  final EmuIntFromSession audioStart;
  final EmuVoidSession audioStop;
  final EmuIntFromSession audioQueued;
  final EmuSetMuted audioSetMuted;
  final EmuIntFromSession audioMuted;
}
