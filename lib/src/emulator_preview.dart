import 'package:common_mvvm/common_mvvm.dart';

import 'emulator_session.dart';
import 'rom_file.dart';

abstract interface class EmulatorPreviewSource {
  EmulatorSession? sessionFor(RomFile rom);
  EmulatorSession? retainPreview(RomFile rom);
  void releasePreview(RomFile rom, EmulatorSession? preview);
}

class EmulatorPreview extends Model {
  EmulatorPreview(EmulatorPreviewSource source, RomFile rom)
    : _source = source,
      _rom = rom,
      _session = source.retainPreview(rom);

  EmulatorPreviewSource _source;
  RomFile _rom;
  EmulatorSession? _session;
  bool _cancelled = false;

  EmulatorSession? get session => _session;

  void update(EmulatorPreviewSource source, RomFile rom) {
    if (_cancelled) return;
    if (identical(_source, source) &&
        _rom == rom &&
        _session != null &&
        identical(_session, source.sessionFor(rom))) {
      return;
    }

    _source.releasePreview(_rom, _session);
    _source = source;
    _rom = rom;
    _session = source.retainPreview(rom);
  }

  @override
  void cancel() {
    if (_cancelled) return;

    _cancelled = true;
    _source.releasePreview(_rom, _session);
    _session = null;
  }
}
