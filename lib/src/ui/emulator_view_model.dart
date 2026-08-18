import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core_library.dart';
import '../emulator_button.dart';
import '../display_style.dart';
import '../emulator_session.dart';
import '../rom_file.dart';
import '../rom_library.dart';

/// Wires the models to the screen and holds nothing else. The shelf, the core
/// lookup and the emulation itself live in [RomLibrary], [CoreLibrary] and
/// [EmulatorSession] — this only forwards.
class EmulatorViewModel extends ChangeNotifier {
  EmulatorViewModel({
    String? corePath,
    String? libraryRoot,
    this.autoPlay = false,
  }) : _library = RomLibrary(rootPath: libraryRoot),
       _cores = CoreLibrary(rootPath: libraryRoot),
       session = EmulatorSession(corePath: corePath) {
    session.addListener(notifyListeners);
    unawaited(refresh());
    if (corePath == null) unawaited(_findCore());
  }

  /// Start the first cartridge as soon as both it and a core are known —
  /// for hosts that open straight into a game rather than the shelf.
  final bool autoPlay;
  bool _autoPlayed = false;

  RomLibrary _library;
  final CoreLibrary _cores;
  final EmulatorSession session;

  List<RomFile> _roms = const [];
  List<RomFile> get roms => _roms;

  RomFile? get playing => session.rom;
  bool get isPaused => session.isPaused;
  bool get isMuted => session.isMuted;
  EmulatorSpeed get speed => session.speed;
  List<String> get logLines => session.logLines;

  /// null is the raw picture; cycling walks the styles and returns to it.
  DisplayStyle? _style;
  DisplayStyle? get style => _style;

  void cycleStyle() {
    final current = _style;
    _style = current == null
        ? DisplayStyle.values.first
        : (current.index == DisplayStyle.values.length - 1
              ? null
              : DisplayStyle.values[current.index + 1]);
    session.log('display ${_style?.label ?? 'raw'}');
    notifyListeners();
  }
  List<EmulatorButton> get buttonLog => session.buttonLog;
  bool get hasGamepad => session.hasGamepad;
  String? get gamepadName => session.gamepadName;
  SessionStatus get status => session.status;

  Future<void> _findCore() async {
    session.corePath = await _cores.first();
    _maybeAutoPlay();
    notifyListeners();
  }

  /// Point the shelf at a different folder — a host that keeps cartridges in
  /// its own document store resolves that path asynchronously, after this
  /// view model already exists.
  Future<void> useRomLibrary(String rootPath) async {
    _library = RomLibrary(rootPath: rootPath);
    await refresh();
  }

  Future<void> refresh() async {
    _roms = await _library.load();
    _maybeAutoPlay();
    notifyListeners();
  }

  void _maybeAutoPlay() {
    if (!autoPlay || _autoPlayed) return;
    if (session.corePath == null || _roms.isEmpty) return;

    _autoPlayed = true;
    session.play(_roms.first);
  }

  Future<void> addFiles(Iterable<String> paths) async {
    _roms = await _library.add(paths);
    session.log('added ${paths.length} file(s)');
    notifyListeners();
  }

  Future<void> remove(RomFile rom) async {
    if (session.rom == rom) session.stop();
    _roms = await _library.remove(rom);
    session.log('removed ${rom.title}');
    notifyListeners();
  }

  void play(RomFile rom) => session.play(rom);
  void pause() => session.pause();
  void resume() => session.resume();
  void togglePause() => session.isPaused ? session.resume() : session.pause();
  void toggleMuted() => session.toggleMuted();
  void cycleSpeed() => session.cycleSpeed();

  /// One slot per cartridge, kept beside it on disk.
  Future<void> saveState() async {
    final rom = session.rom;
    final state = session.saveState();
    if (rom == null || state == null) return;
    await File('${rom.path}.state').writeAsBytes(state);
  }

  Future<void> loadState() async {
    final rom = session.rom;
    if (rom == null) return;

    final file = File('${rom.path}.state');
    if (!file.existsSync()) {
      session.log('no saved state');
      return;
    }
    session.loadState(await file.readAsBytes());
  }
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
