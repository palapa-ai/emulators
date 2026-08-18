import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core_library.dart';
import '../emulator_button.dart';
import '../emulator_session.dart';
import '../rom_file.dart';
import '../rom_library.dart';

/// Wires the models to the screen and holds nothing else. The shelf, the core
/// lookup and the emulation itself live in [RomLibrary], [CoreLibrary] and
/// [EmulatorSession] — this only forwards.
class EmulatorViewModel extends ChangeNotifier {
  EmulatorViewModel({String? corePath, String? libraryRoot})
    : _library = RomLibrary(rootPath: libraryRoot),
      _cores = CoreLibrary(rootPath: libraryRoot),
      session = EmulatorSession(corePath: corePath) {
    session.addListener(notifyListeners);
    unawaited(refresh());
    if (corePath == null) unawaited(_findCore());
  }

  final RomLibrary _library;
  final CoreLibrary _cores;
  final EmulatorSession session;

  List<RomFile> _roms = const [];
  List<RomFile> get roms => _roms;

  RomFile? get playing => session.rom;
  SessionStatus get status => session.status;

  Future<void> _findCore() async {
    session.corePath = await _cores.first();
    notifyListeners();
  }

  Future<void> refresh() async {
    _roms = await _library.load();
    notifyListeners();
  }

  Future<void> addFiles(Iterable<String> paths) async {
    _roms = await _library.add(paths);
    notifyListeners();
  }

  Future<void> remove(RomFile rom) async {
    if (session.rom == rom) session.stop();
    _roms = await _library.remove(rom);
    notifyListeners();
  }

  void play(RomFile rom) => session.play(rom);
  void stop() => session.stop();
  void reset() => session.reset();

  void press(EmulatorButton button, {required bool pressed}) =>
      session.press(button, pressed: pressed);

  @override
  void dispose() {
    session.removeListener(notifyListeners);
    session.dispose();
    super.dispose();
  }
}
