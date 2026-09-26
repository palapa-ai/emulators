import 'package:common_mvvm/common_mvvm.dart';

import '../emulator_preview.dart';
import '../emulator_session.dart';
import '../rom_file.dart';

class EmulatorPreviewViewModel extends ViewModel {
  EmulatorPreviewViewModel(EmulatorPreviewSource source, RomFile rom)
    : _preview = EmulatorPreview(source, rom);

  final EmulatorPreview _preview;

  EmulatorSession? get session => _preview.session;

  void update(EmulatorPreviewSource source, RomFile rom) =>
      _preview.update(source, rom);

  @override
  void cancel() => _preview.cancel();
}
