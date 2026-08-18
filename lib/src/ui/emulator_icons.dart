import 'dart:convert';
import 'dart:typed_data';

/// 32x32 PNGs kept inline: four small images are not worth an asset
/// bundle, and this way the package carries its own icons.
class EmulatorIcons {
  const EmulatorIcons._();

  static final Uint8List snes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAeUlEQVR42mNgGAWj'
      'YBSMglEwWMGdm1f+UxPT3fKTR96Q5wh0TaHBUXBMiuUwTLIjqOEAXCFAsgOQLSfG'
      'EbgszYk+QpwD8PmekANwBTvIchgm2RF0DwFqpgFkS+meCLEFO0VZkRxMtuXYHENJ'
      'aTpap4yCUTAKRgEhAAAcLQ3FQCbEcAAAAABJRU5ErkJggg==',
  );

  static final Uint8List nes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAYUlEQVR42mNgGAWj'
      'YBSMglEwWMGNSyf+UxMPqOUkOQJdU2hwFBzTxRGDygHIllPLEWT7nhQHHLDUxsun'
      'aQiALINhbHy6pAF8ITD4E+GAlwPYHENJaTpap4yCUTAKRgEhAADeHvhvP3R7ywAA'
      'AABJRU5ErkJggg==',
  );

  static final Uint8List n64 = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAgklEQVR42mNgGAWj'
      'YBSMglEwWMH5M8f+UxMPqOUkOQJdU2hwFByTYplO/g3yHEENB4Ash2GKHIBsOTmO'
      'IDkE8PmeGAfcOK6D3TELvMhzBCkOAFkOw+iWwzDN0wAxIUC3XHDAUpt6WZFUDLIc'
      'hskujJAdQ44+mOWjdcooGAWjYBQQAgCMH+a+Kd9l7AAAAABJRU5ErkJggg==',
  );

  static final Uint8List copy = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAARElEQVR42mNgGAWj'
      'AA/Yv+fEf1Lx8HSAiJAUQTzqAJpEy5B0AFWjZdQBow4YdcCgcQApeHg5YLSGHG0l'
      'jYJRMApGBAAAB7vYy5GqX5kAAAAASUVORK5CYII=',
  );

}
