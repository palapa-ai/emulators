import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core_library.dart';
import '../display_style.dart';
import '../emulator_agent.dart';
import '../emulator_assistant.dart';
import '../emulator_button.dart';
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
  final EmulatorSession _focused;

  EmulatorSession get session => _focused;

  /// The playing cartridge answers with the focused session, so its card
  /// shows the same picture as the screen rather than going blank.
  EmulatorSession? sessionFor(RomFile rom) =>
      rom.path == _focused.rom?.path ? _focused : _sessions[rom.path];

  bool _previewsRunning = true;
  bool get previewsRunning => _previewsRunning;

  Future<void> togglePreviews() async {
    _previewsRunning ? _stopPreviews() : await _startPreviews();
    notifyListeners();
  }

  /// Emulating a shelf nobody is looking at is pure waste, so previews only
  /// cover cards the host has put on screen, and never more than this many at
  /// once — each one is a whole core with its own copy of the ROM.
  static const maxPreviews = 8;

  final _visible = <String>{};
  var _syncQueued = false;

  /// Called by a card as it scrolls into and out of the viewport. A scroll
  /// moves many at once, so the sessions are reconciled once at the end.
  void showPreview(RomFile rom) {
    if (_visible.add(rom.path)) _queueSync();
  }

  void hidePreview(RomFile rom) {
    if (_visible.remove(rom.path)) _queueSync();
  }

  void _queueSync() {
    if (_syncQueued) return;
    _syncQueued = true;
    scheduleMicrotask(() async {
      _syncQueued = false;
      if (_previewsRunning) await _startPreviews();
      notifyListeners();
    });
  }

  Future<void> _startPreviews() async {
    _previewsRunning = true;
    final core = session.corePath;
    if (core == null) return;

    final keep = _roms
        .where((r) => _visible.contains(r.path) && r.path != _focused.rom?.path)
        .take(maxPreviews)
        .map((r) => r.path)
        .toSet();

    for (final entry in _sessions.entries.toList()) {
      if (entry.key == _focusKey || keep.contains(entry.key)) continue;
      _park(entry.value, _previewSlot);
      entry.value.dispose();
      _sessions.remove(entry.key);
    }

    final wanted = _roms
        .where((r) => _visible.contains(r.path) && r.path != _focused.rom?.path)
        .take(maxPreviews);

    for (final rom in wanted) {
      if (rom.path == _focused.rom?.path || _sessions.containsKey(rom.path)) {
        continue;
      }

      // No global listener: each shelf card watches its own preview, so a
      // frame repaints one thumbnail instead of the entire shelf.
      final preview = EmulatorSession(corePath: core, preview: true)..play(rom);
      _sessions[rom.path] = preview;

      // A cartridge the player has been inside comes back to where they left
      // it and stops there. Only the ones never played keep running, so the
      // shelf demonstrates what is unopened instead of restarting your game.
      final played = hasState(rom, _resumeSlot);
      await _resume(preview, rom, played ? _resumeSlot : _previewSlot);
      if (played) preview.pauseOnNextFrame();
    }
  }

  void _stopPreviews() {
    _previewsRunning = false;
    for (final entry in _sessions.entries.toList()) {
      if (entry.key == _focusKey) continue;
      _park(entry.value, _previewSlot);
      entry.value.dispose();
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

  /// The picture alone, filling the screen — the shelf, the panels and the
  /// host's own chrome all step out of the way until it is turned off.
  bool _fullscreen = false;
  bool get fullscreen => _fullscreen;

  void toggleFullscreen() {
    _fullscreen = !_fullscreen;
    notifyListeners();
  }

  /// null is the raw picture; cycling walks the styles and returns to it.
  DisplayStyle? _style = DisplayStyle.vhs;
  DisplayStyle? get style => _style;

  void cycleStyle({bool reverse = false}) {
    final current = _style;
    final last = DisplayStyle.values.length - 1;
    _style = switch ((current, reverse)) {
      (null, false) => DisplayStyle.values.first,
      (null, true) => DisplayStyle.values.last,
      (final style?, false) when style.index == last => null,
      (final style?, true) when style.index == 0 => null,
      (final style?, false) => DisplayStyle.values[style.index + 1],
      (final style?, true) => DisplayStyle.values[style.index - 1],
    };
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
      final reply = await assistant.ask(
        question,
        EmulatorAssistantContext(
          romTitle: session.rom?.title ?? 'no cartridge',
          system: RomSystem.of(session.rom?.path ?? '')?.label ?? 'unknown',
          coreName: session.coreName,
          logLines: session.logLines.length > 20
              ? session.logLines.sublist(session.logLines.length - 20)
              : session.logLines,
          recentButtons: [for (final b in session.padLog) b.label],
        ),
      );
      for (final call in reply.calls) {
        await agent.run(call);
      }
      return reply.answer;
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

  Future<void> play(RomFile rom) async {
    // Always the dedicated session. Adopting the running preview looked like
    // a free swap, but a preview is half resolution with no sound — promoting
    // one put a thumbnail on the screen, and left the cartridge you stepped
    // away from emulating at full rate for nobody.
    final parked = _focused.rom;
    if (parked != null && _focused.isRunning) {
      session.log('parked ${parked.title}');
    }
    _park(_focused, _resumeSlot);
    _focused.play(rom);
    final resumed = hasState(rom, _resumeSlot);
    await _resume(_focused, rom, _resumeSlot);
    if (resumed) session.log('resumed ${rom.title}');
    if (_previewsRunning) await _startPreviews();
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

  /// Two more the shelf never shows. A preview parks in one as it scrolls
  /// away so it carries on instead of rebooting, and the cartridge you step
  /// away from parks in the other so clicking it puts you back where you were.
  static const _previewSlot = 4;
  static const _resumeSlot = 5;

  // Silent: previews park and resume constantly as the shelf scrolls, and a
  // log that narrates them buries the player's own actions. play() speaks for
  // the one move the player made.
  void _park(EmulatorSession target, int slot) {
    final rom = target.rom;
    if (rom == null || !target.isRunning) return;
    final state = target.saveState();
    if (state == null) return;
    unawaited(File(_slotPath(rom, slot)).writeAsBytes(state));
  }

  Future<void> _resume(EmulatorSession target, RomFile rom, int slot) async {
    final file = File(_slotPath(rom, slot));
    if (!file.existsSync()) return;
    target.loadState(await file.readAsBytes());
  }

  String _slotPath(RomFile rom, int slot) => '${rom.path}.state$slot';

  bool hasState(RomFile rom, int slot) =>
      File(_slotPath(rom, slot)).existsSync();

  Future<void> saveState(int slot) async {
    final rom = session.rom;
    final state = session.saveState();
    if (rom == null || state == null) return;

    await File(_slotPath(rom, slot)).writeAsBytes(state);
    session.log('saved #$slot');
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
    for (final session in _sessions.values) {
      session
        ..removeListener(notifyListeners)
        ..dispose();
    }
    super.dispose();
  }
}
