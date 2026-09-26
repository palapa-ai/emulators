import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../core_library.dart';
import '../display_style.dart';
import '../emulator_agent.dart';
import '../emulator_assistant.dart';
import '../emulator_button.dart';
import '../emulator_previews.dart';
import '../emulator_session.dart';
import '../pad_element.dart';
import '../rom_file.dart';
import '../rom_library.dart';
import '../rom_portraits.dart';

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
    _focused.addListener(notifyListeners);
    unawaited(refresh());
    if (corePath == null) unawaited(_findCore());
  }

  final _previews = EmulatorPreviews();
  bool _disposed = false;
  final EmulatorSession _focused;

  EmulatorSession get session => _focused;

  /// The playing cartridge answers with the focused session, so its card
  /// shows the same picture as the screen rather than going blank.
  EmulatorSession? sessionFor(RomFile rom) =>
      rom.path == _focused.rom?.path ? _focused : _previews.sessionFor(rom);

  EmulatorSession? retainPreview(RomFile rom) => rom.path == _focused.rom?.path
      ? _focused
      : _previews.retain(rom, session.corePath);

  void releasePreview(RomFile rom, EmulatorSession? preview) =>
      _previews.release(rom, preview);

  void stopPreviews() => _previews.stop();

  RomPortraits? _portraits;
  final _pictures = <String, ui.Image>{};
  var _loadingPictures = false;

  /// The cartridge's own picture, once it has one.
  ui.Image? pictureOf(RomFile rom) => _pictures[rom.path];

  Future<void> _loadPictures() async {
    final core = session.corePath;
    if (core == null || _loadingPictures || _disposed) return;

    _loadingPictures = true;
    final portraits = _portraits ??= RomPortraits(corePath: core);

    try {
      await Future.forEach(_roms, (rom) async {
        if (_disposed) return;

        final picture = await portraits.load(rom);
        if (picture == null) return;
        if (_disposed) {
          picture.dispose();
          return;
        }

        _pictures.remove(rom.path)?.dispose();
        _pictures[rom.path] = picture;
        notifyListeners();
      });
    } finally {
      _loadingPictures = false;
    }
  }

  /// What the player last saw, so the shelf shows where they left off rather
  /// than the title screen they have not looked at since the first boot.
  Future<void> _repicture(EmulatorSession from) async {
    final rom = from.rom;
    final frame = from.frames.value;
    final portraits = _portraits;
    if (rom == null || frame == null || portraits == null) return;

    await portraits.save(rom, frame);
    final picture = await portraits.load(rom);
    if (picture == null) return;

    _pictures[rom.path] = picture;
    notifyListeners();
  }

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
  late final EmulatorAgent agent = EmulatorAgent(_focused);

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
          recentButtons: [for (final b in session.padLog) b.label],
          picture: await agent.screenshot(),
        ),
      );
    }();
  }

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

    session.corePath = core;
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
    notifyListeners();
  }

  Future<void> refresh() async {
    final roms = await _library.load();
    if (_disposed) return;

    _roms = roms;
    _maybeAutoPlay();
    notifyListeners();
    unawaited(_loadPictures());
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

  Future<void> play(RomFile rom) async {
    // Always the dedicated session. Adopting the running preview looked like
    // a free swap, but a preview is half resolution with no sound — promoting
    // one put a thumbnail on the screen, and left the cartridge you stepped
    // away from emulating at full rate for nobody.
    final parked = _focused.rom;
    if (parked != null && _focused.isRunning) {
      session.log('parked ${parked.title}');
      await _repicture(_focused);
    }
    _park(_focused, _resumeSlot);
    _rememberLastPlayed(rom);
    _focused.play(rom);
    final resumed = hasState(rom, _resumeSlot);
    await _resume(_focused, rom, _resumeSlot);
    if (resumed) session.log('resumed ${rom.title}');
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

  /// One more the shelf never shows: the cartridge you step away from parks
  /// here, so clicking it puts you back where you were.
  static const _resumeSlot = 5;

  // Silent: a park happens on every swap, and a log that narrates them buries
  // the player's own actions. play() speaks for the one move they made.
  void _park(EmulatorSession target, int slot) {
    final rom = target.rom;
    if (rom == null || !target.isRunning) return;
    final state = target.saveState();
    if (state == null) return;
    unawaited(File(_slotPath(rom, slot)).writeAsBytes(state));
  }

  Future<void> _resume(EmulatorSession target, RomFile rom, int slot) async {
    final file = File(
      rom.existingSidecar('.state$slot') ?? _slotPath(rom, slot),
    );
    if (!file.existsSync()) return;
    target.loadState(await file.readAsBytes());
  }

  String _slotPath(RomFile rom, int slot) => '${rom.path}.state$slot';

  bool hasState(RomFile rom, int slot) =>
      rom.existingSidecar('.state$slot') != null;

  final Map<(String, int), String> saveFeedback = {};

  Future<void> saveState(int slot) async {
    final rom = session.rom;
    if (rom == null || slot < 1 || slot > slotCount) return;
    final key = (rom.path, slot);
    if (saveFeedback[key] == 'Saving') return;
    saveFeedback[key] = 'Saving';
    notifyListeners();
    try {
      final state = session.saveState();
      if (state == null) throw StateError('No save state available');
      await File(_slotPath(rom, slot)).writeAsBytes(state, flush: true);
      saveFeedback[key] = 'Saved';
      session.log('saved #$slot');
    } catch (error) {
      saveFeedback[key] = 'Save failed';
      session.log('could not save #$slot: $error');
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> loadState(int slot, {RomFile? from}) async {
    final rom = from ?? session.rom;
    if (rom == null) return;

    final file = File(
      rom.existingSidecar('.state$slot') ?? _slotPath(rom, slot),
    );
    if (!file.existsSync()) {
      session.log('slot $slot is empty');
      return;
    }

    if (from != null && from.path != session.rom?.path) await play(from);
    if (session.loadState(await file.readAsBytes()))
      session.log('loaded #$slot');
  }

  void stop() => session.stop();
  void reset() => session.reset();

  void press(EmulatorButton button, {required bool pressed}) =>
      session.press(button, pressed: pressed);

  @override
  void dispose() {
    _disposed = true;
    _previews.dispose();
    _focused
      ..removeListener(notifyListeners)
      ..dispose();
    _pictures.values.forEach((picture) => picture.dispose());
    _pictures.clear();
    super.dispose();
  }
}
