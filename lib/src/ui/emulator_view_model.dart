import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../core_library.dart';
import '../display_style.dart';
import '../emulator_agent.dart';
import '../emulator_assistant.dart';
import '../emulator_button.dart';
import '../emulator_collection.dart';
import '../emulator_preview.dart';
import '../emulator_session.dart';
import '../pad_element.dart';
import '../player_controls.dart';
import '../rom_file.dart';
import '../rom_library.dart';
import '../save_feedback.dart';

/// Wires the models to the screen and holds nothing else. The shelf, the core
/// lookup and the emulation itself live in [RomLibrary], [CoreLibrary] and
/// [EmulatorSession] — this only forwards.
class EmulatorViewModel extends ChangeNotifier
    implements EmulatorPreviewSource {
  EmulatorViewModel({
    String? corePath,
    String? libraryRoot,
    this.autoPlay = false,
  }) : _library = RomLibrary(rootPath: libraryRoot),
       _cores = CoreLibrary(rootPath: libraryRoot),
       _collection = EmulatorCollection(corePath: corePath) {
    _collection.addListener(notifyListeners);
    unawaited(refresh());
    if (corePath == null) unawaited(_findCore());
  }

  final EmulatorCollection _collection;
  bool _disposed = false;

  EmulatorSession get session => _collection.session;

  EmulatorSession? sessionFor(RomFile rom) => _collection.sessionFor(rom);

  ui.Image? pictureOf(RomFile rom) => _collection.pictureOf(rom);

  // The collection owns a fixed pool; cards borrow it without starting runtimes.
  EmulatorSession? retainPreview(RomFile rom) => _collection.sessionFor(rom);

  void releasePreview(RomFile rom, EmulatorSession? preview) {}

  void stopPreviews() => _collection.stopPreviews();

  /// Start the first cartridge as soon as both it and a core are known —
  /// for hosts that open straight into a game rather than the shelf.
  final bool autoPlay;
  bool _autoPlayed = false;

  RomLibrary _library;
  CoreLibrary _cores;

  List<RomFile> _roms = const [];
  List<RomFile> get roms => _roms;

  RomFile? get playing => session.rom;
  bool get isPaused => session.isPaused;
  bool get isMuted => session.isMuted;
  EmulatorSpeed get speed => session.speed;
  List<String> get logLines => session.logLines;

  /// The player's answer, and only that — nothing here captures play yet.
  /// A host that records (frame, action) pairs reads this before it starts,
  /// and it defaults to no.
  bool _sharesTrainingData = false;
  bool get sharesTrainingData => _sharesTrainingData;

  void toggleTrainingData() {
    _sharesTrainingData = !_sharesTrainingData;
    session.log(
      _sharesTrainingData
          ? 'sharing training data'
          : 'not sharing training data',
    );
    notifyListeners();
  }

  /// A console's pixels were never square — a SNES drew 256 across a screen
  /// four units wide by three tall, so the tube stretched them. Showing the
  /// frame at its own ratio is the faithful-to-the-file view; 4:3 is the
  /// faithful-to-the-television one, and the one people remember.
  bool _squarePixels = false;
  bool get squarePixels => _squarePixels;

  /// The shape to draw the picture in, whatever shape the core handed over.
  double aspectFor(int width, int height) =>
      _squarePixels ? width / height : 4 / 3;

  void togglePixelShape() {
    _squarePixels = !_squarePixels;
    session.log(_squarePixels ? 'square pixels' : '4:3');
    notifyListeners();
  }

  /// The picture alone, filling the screen — the shelf, the panels and the
  /// host's own chrome all step out of the way until it is turned off.
  bool _fullscreen = false;
  bool get fullscreen => _fullscreen;

  void toggleFullscreen() {
    _fullscreen = !_fullscreen;
    notifyListeners();
  }

  /// null is the raw picture; cycling walks the styles and returns to it.
  DisplayStyle? _style;
  DisplayStyle? get style => _style;

  void cycleStyle({bool reverse = false}) {
    final cycle = <DisplayStyle?>[null, ...DisplayStyle.cycleOrder];
    final index = cycle.indexOf(_style);
    _style = index < 0
        ? null
        : cycle[(index + (reverse ? -1 : 1)) % cycle.length];
    final audio = _style?.audio ?? StyleAudio.clean;
    session.setAudioQuality(bits: audio.bits, mono: audio.mono);
    session.log(_style?.label.toLowerCase() ?? 'raw');
    notifyListeners();
  }

  List<EmulatorButton> get buttonLog => session.buttonLog;
  List<PadElement> get padLog => session.padLog;

  /// Hosts hand one in — Palapa its own harness, the workbench an
  /// [HttpAssistant] built from whatever endpoint the user typed.
  EmulatorAssistant? assistant;

  /// The assistant's hands: memory, controls, screenshots, save states,
  /// always against the game on screen.
  late final EmulatorAgent agent = EmulatorAgent(session);

  /// Null when no assistant is connected. Whatever the reply asked to do is
  /// done before the answer comes back, so the text can describe the result.
  Future<String>? askAssistant(String question) {
    final assistant = this.assistant;
    if (assistant == null) return null;

    return () async {
      return agent.converse(
        assistant,
        question,
        EmulatorAssistantContext(
          romTitle: session.rom?.title ?? 'no cartridge',
          system: RomSystem.of(session.rom?.path ?? '')?.label ?? 'unknown',
          coreName: session.coreName,
          logLines: session.logLines.length > 20
              ? session.logLines.sublist(session.logLines.length - 20)
              : session.logLines,
          recentButtons: session.padLog.map((button) => button.label).toList(),
          picture: await agent.screenshot(),
        ),
      );
    }();
  }

  PlayerControls controlsFor(EmulatorPlayer player) =>
      session.controlsFor(player);
  String? padNameFor(EmulatorPlayer player) => session.padNameFor(player);
  void assignPlayer(EmulatorPlayer player, ControllerDriver driver) =>
      session.assignPlayer(player, driver);

  int get heldMask => session.heldMask;
  int get padMask => session.padMask;
  String? get padName => session.padName;
  int get keyboardMask => session.keyboardMask;
  bool get isCollecting => session.isCollecting;

  void toggleCollecting() => session.toggleCollecting();
  bool get hasGamepad => session.hasGamepad;
  String? get gamepadName => session.gamepadName;
  SessionStatus get status => session.status;

  Future<void> _findCore() async {
    final core = await _cores.first();
    if (_disposed) return;
    _collection.useCore(core);
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

  /// Point the core lookup at a different folder. A host keeps its cores
  /// where it keeps its own data, which it only knows asynchronously.
  Future<void> useCoreLibrary(String rootPath) async {
    _cores = CoreLibrary(rootPath: rootPath);
    if (session.corePath == null) await _findCore();
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> refresh() async {
    final roms = await _library.load();
    if (_disposed) return;
    _roms = roms;
    _maybeAutoPlay();
    notifyListeners();
    _collection.setRoms(_roms, lastPlayed: _lastPlayed);
  }

  // Opening the shelf puts you back in the game you were last in, at the
  // moment you left it — a console remembers what is in the slot.
  void _maybeAutoPlay() {
    if (!autoPlay || _autoPlayed) return;
    if (session.corePath == null || _roms.isEmpty) return;

    _autoPlayed = true;
    unawaited(play(_lastPlayed ?? _roms.first));
  }

  static const _lastPlayedFile = '.last-played';

  RomFile? get _lastPlayed {
    final file = File('${_library.rootPath}/$_lastPlayedFile');
    if (_library.rootPath == null || !file.existsSync()) return null;
    final path = file.readAsStringSync().trim();
    return _roms.where((r) => r.allPaths.contains(path)).firstOrNull;
  }

  void _rememberLastPlayed(RomFile rom) {
    final root = _library.rootPath;
    if (root == null) return;
    unawaited(File('$root/$_lastPlayedFile').writeAsString(rom.path));
  }

  Future<void> addFiles(Iterable<String> paths) async {
    final roms = await _library.add(paths);
    if (_disposed) return;
    _roms = roms;
    _collection.setRoms(_roms, lastPlayed: _lastPlayed);
    session.log('added ${paths.length} file(s)');
    notifyListeners();
  }

  Future<void> remove(RomFile rom) async {
    if (session.rom == rom) session.stop();
    final roms = await _library.remove(rom);
    if (_disposed) return;
    _roms = roms;
    _collection.setRoms(_roms, lastPlayed: _lastPlayed);
    session.log('removed ${rom.title}');
    notifyListeners();
  }

  Future<void> play(RomFile rom) async {
    await _collection.play(rom);
    if (_disposed) return;
    if (session.rom == rom) _rememberLastPlayed(rom);
    notifyListeners();
  }

  void pause() => session.pause();
  void resume() => session.resume();
  void togglePause() => session.isPaused ? session.resume() : session.pause();
  void toggleMuted() => session.toggleMuted();
  void cycleSpeed({bool reverse = false}) =>
      session.cycleSpeed(reverse: reverse);

  /// Three slots per cartridge, kept beside it on disk.
  static const slotCount = 3;

  String _slotPath(RomFile rom, int slot) =>
      EmulatorCollection.statePath(rom, slot);

  bool hasState(RomFile rom, int slot) =>
      rom.existingSidecar('.state$slot') != null;

  final Map<(String, int), SaveFeedback> saveFeedback = {};

  Future<bool> saveState(int slot) async {
    final rom = session.rom;
    if (rom == null || slot < 1 || slot > slotCount) return false;
    final key = (rom.path, slot);
    if (saveFeedback[key] == .saving) return false;
    saveFeedback[key] = .saving;
    notifyListeners();
    try {
      final state = session.saveState();
      if (state == null) throw StateError('No save state available');
      final path = _slotPath(rom, slot);
      await File('$path.tmp').writeAsBytes(state, flush: true);
      await File('$path.tmp').rename(path);
      if (_disposed) return false;
      saveFeedback[key] = .saved;
      session.log('saved #$slot');
      notifyListeners();
      return true;
    } catch (error) {
      if (!_disposed) {
        saveFeedback[key] = .failed;
        session.log('could not save #$slot: $error');
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> loadState(int slot, {RomFile? from}) async {
    final rom = from ?? session.rom;
    if (rom == null) return false;

    final file = File(
      rom.existingSidecar('.state$slot') ?? _slotPath(rom, slot),
    );
    if (!file.existsSync()) {
      session.log('slot $slot is empty');
      return false;
    }

    try {
      final state = await file.readAsBytes();
      if (_disposed) return false;
      if (from != null && from.path != session.rom?.path) await play(from);
      if (_disposed || session.rom != rom || !session.loadState(state)) {
        return false;
      }
      session.log('loaded #$slot');
      return true;
    } on Object catch (error) {
      if (!_disposed) session.log('could not load #$slot: $error');
      return false;
    }
  }

  void stop() => _collection.stop();
  void reset() => session.reset();

  void press(
    EmulatorButton button, {
    required bool pressed,
    EmulatorPlayer player = .p1,
  }) => session.press(button, pressed: pressed, player: player);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _collection
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}
