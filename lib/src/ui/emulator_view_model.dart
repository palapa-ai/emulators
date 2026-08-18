import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core_library.dart';
import '../emulator_button.dart';
import '../display_style.dart';
import '../emulator_session.dart';
import '../pad_element.dart';
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
       _focused = EmulatorSession(corePath: corePath) {
    _sessions[_focusKey] = _focused;
    _focused.addListener(notifyListeners);
    unawaited(refresh());
    if (corePath == null) unawaited(_findCore());
  }

  static const _focusKey = '';

  /// One session per cartridge, so every shelf card can show a live picture.
  /// Only the focused one is audible — several soundtracks at once is noise.
  final _sessions = <String, EmulatorSession>{};
  EmulatorSession _focused;

  EmulatorSession get session => _focused;

  EmulatorSession? sessionFor(RomFile rom) => _sessions[rom.path];

  bool _previewsRunning = true;
  bool get previewsRunning => _previewsRunning;

  Future<void> togglePreviews() async {
    _previewsRunning ? _stopPreviews() : await _startPreviews();
    notifyListeners();
  }

  /// Emulating a shelf nobody is looking at is pure waste, so previews are
  /// capped and only cover what the host says is on screen.
  static const maxPreviews = 3;

  var _visible = <String>{};

  Future<void> setVisible(Iterable<RomFile> roms) async {
    final wanted = roms.take(maxPreviews).map((r) => r.path).toSet();
    if (_setEquals(wanted, _visible)) return;

    _visible = wanted;
    if (_previewsRunning) await _startPreviews();
    notifyListeners();
  }

  bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.every(b.contains);

  Future<void> _startPreviews() async {
    _previewsRunning = true;
    final core = session.corePath;
    if (core == null) return;

    for (final entry in _sessions.entries.toList()) {
      if (entry.key == _focusKey || _visible.contains(entry.key)) continue;
      entry.value
        ..removeListener(notifyListeners)
        ..dispose();
      _sessions.remove(entry.key);
    }

    for (final rom in _roms.where((r) => _visible.contains(r.path))) {
      if (rom.path == _focused.rom?.path || _sessions.containsKey(rom.path)) {
        continue;
      }

      final preview = EmulatorSession(corePath: core, preview: true)
        ..addListener(notifyListeners)
        ..play(rom);
      _sessions[rom.path] = preview;
    }
  }

  void _stopPreviews() {
    _previewsRunning = false;
    for (final entry in _sessions.entries.toList()) {
      if (entry.key == _focusKey) continue;
      entry.value
        ..removeListener(notifyListeners)
        ..dispose();
      _sessions.remove(entry.key);
    }
  }

  /// Start the first cartridge as soon as both it and a core are known —
  /// for hosts that open straight into a game rather than the shelf.
  final bool autoPlay;
  bool _autoPlayed = false;

  RomLibrary _library;
  final CoreLibrary _cores;


  List<RomFile> _roms = const [];
  List<RomFile> get roms => _roms;

  RomFile? get playing => session.rom;
  bool get isPaused => session.isPaused;
  bool get isMuted => session.isMuted;
  EmulatorSpeed get speed => session.speed;
  List<String> get logLines => session.logLines;

  /// null is the raw picture; cycling walks the styles and returns to it.
  DisplayStyle? _style = DisplayStyle.vhs;
  DisplayStyle? get style => _style;

  void cycleStyle() {
    final current = _style;
    _style = current == null
        ? DisplayStyle.values.first
        : (current.index == DisplayStyle.values.length - 1
              ? null
              : DisplayStyle.values[current.index + 1]);
    final audio = _style?.audio ?? StyleAudio.clean;
    session.setAudioQuality(bits: audio.bits, mono: audio.mono);
    session.log('display ${_style?.label ?? 'raw'}');
    notifyListeners();
  }
  List<EmulatorButton> get buttonLog => session.buttonLog;
  List<PadElement> get padLog => session.padLog;
  int get heldMask => session.heldMask;
  int get padMask => session.padMask;
  List<String> get padKeys => session.padKeys;
  int get keyboardMask => session.keyboardMask;
  bool get isCollecting => session.isCollecting;

  void toggleCollecting() => session.toggleCollecting();
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
    if (_previewsRunning) await _startPreviews();
    notifyListeners();
  }

  void _maybeAutoPlay() {
    if (!autoPlay || _autoPlayed) return;
    if (session.corePath == null || _roms.isEmpty) return;

    _autoPlayed = true;
    session.play(_roms.first);
    unawaited(_startPreviews());
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

  void play(RomFile rom) {
    // A preview already running this cartridge becomes the focused session
    // rather than being torn down and started over.
    final existing = _sessions[rom.path];
    if (existing != null && existing != _focused) {
      _focused.setMuted(muted: true);
      _focused = existing;
      existing.setMuted(muted: false);
      notifyListeners();
      return;
    }

    _focused.play(rom);
  }
  void pause() => session.pause();
  void resume() => session.resume();
  void togglePause() => session.isPaused ? session.resume() : session.pause();
  void toggleMuted() => session.toggleMuted();
  void cycleSpeed() => session.cycleSpeed();

  /// Three slots per cartridge, kept beside it on disk.
  static const slotCount = 3;

  String _slotPath(RomFile rom, int slot) => '${rom.path}.state$slot';

  bool hasState(RomFile rom, int slot) =>
      File(_slotPath(rom, slot)).existsSync();

  Future<void> saveState(int slot) async {
    final rom = session.rom;
    final state = session.saveState();
    if (rom == null || state == null) return;

    await File(_slotPath(rom, slot)).writeAsBytes(state);
    session.log('saved slot $slot');
    notifyListeners();
  }

  Future<void> loadState(int slot, {RomFile? from}) async {
    final rom = from ?? session.rom;
    if (rom == null) return;

    final file = File(_slotPath(rom, slot));
    if (!file.existsSync()) {
      session.log('slot $slot is empty');
      return;
    }

    if (from != null && from.path != session.rom?.path) play(from);
    session.loadState(await file.readAsBytes());
  }
  void stop() => session.stop();
  void reset() => session.reset();

  void press(EmulatorButton button, {required bool pressed}) =>
      session.press(button, pressed: pressed);

  @override
  void dispose() {
    for (final session in _sessions.values) {
      session
        ..removeListener(notifyListeners)
        ..dispose();
    }
    super.dispose();
  }
}
