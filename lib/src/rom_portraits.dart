import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'emulator.dart';
import 'rom_file.dart';

/// The picture a cartridge shows on the shelf, kept beside it on disk.
///
/// The shelf used to emulate every card it could see — a whole core each,
/// running a game nobody was playing, to fill a thumbnail. A cartridge keeps
/// its last frame as a file instead, and one that has never been opened is
/// booted once, photographed, and closed.
class RomPortraits {
  RomPortraits({required this.corePath});

  final String corePath;

  /// Far enough in for a title screen to be up. Photographed on its first
  /// frame every cartridge is black.
  static const _bootFrames = 240;

  /// Long enough that a boot does not hold a frame, short enough that the
  /// shelf fills while the player is still looking at it.
  static const _framesPerSlice = 30;

  File _fileFor(RomFile rom) => File('${rom.path}.png');

  bool has(RomFile rom) => _fileFor(rom).existsSync();

  Future<void> save(RomFile rom, ui.Image frame) async {
    final data = await frame.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    await _fileFor(rom).writeAsBytes(data.buffer.asUint8List());
  }

  Future<ui.Image?> load(RomFile rom) async {
    final file = _fileFor(rom);
    if (!file.existsSync()) return null;

    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    return (await codec.getNextFrame()).image;
  }

  /// Boot, run as far as a picture, photograph, close. One cartridge at a
  /// time, giving the frame back between slices so the app keeps drawing.
  Future<void> capture(RomFile rom) async {
    final emulator = Emulator.open(corePath: corePath, romPath: rom.path);

    try {
      for (var frame = 0; frame < _bootFrames; frame++) {
        emulator.runFrame();
        if (frame % _framesPerSlice == _framesPerSlice - 1) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      final image = await _decode(emulator);
      if (image != null) await save(rom, image);
    } finally {
      emulator.close();
    }
  }

  Future<ui.Image?> _decode(Emulator emulator) {
    final pixels = emulator.frame;
    final width = emulator.frameWidth;
    final height = emulator.frameHeight;
    if (pixels == null || width <= 0 || height <= 0) return Future.value();

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels.buffer.asUint8List(0, width * height * 4),
      width,
      height,
      ui.PixelFormat.bgra8888,
      completer.complete,
    );
    return completer.future;
  }
}
