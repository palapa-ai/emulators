import 'dart:io';
import 'dart:ui' as ui;

import 'rom_file.dart';

class RomPortraits {
  File _fileFor(RomFile rom) => File('${rom.path}.png');

  Future<void> save(RomFile rom, ui.Image frame) async {
    final data = await frame.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    await _fileFor(rom).writeAsBytes(data.buffer.asUint8List());
  }

  Future<ui.Image?> load(RomFile rom) async {
    final file = _fileFor(rom);
    if (!file.existsSync()) return null;

    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }
}
