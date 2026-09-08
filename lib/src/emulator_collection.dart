import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'emulator_session.dart';
import 'rom_file.dart';
import 'rom_portraits.dart';

class EmulatorCollection extends ChangeNotifier {
  EmulatorCollection({String? corePath})
    : session = EmulatorSession(corePath: corePath),
      _previews = List.generate(
        runtimeLimit - 1,
        (_) => EmulatorSession(corePath: corePath, preview: true),
      ) {
    session.addListener(notifyListeners);
  }

  static const runtimeLimit = 3;
  static const previewTurn = Duration(seconds: 3);
  static const resumeSlot = 5;

  final EmulatorSession session;
  final List<EmulatorSession> _previews;
  final _visited = <String>{};
  final _previewStates = <String, Uint8List>{};
  final _pictures = <String, ui.Image>{};
  final _failed = <String>{};
  List<RomFile> _roms = const [];
  Timer? _rotation;
  int _next = 0;
  bool _disposed = false;

  EmulatorSession? sessionFor(RomFile rom) =>
      [session, ..._previews].where((s) => s.rom == rom).firstOrNull;

  ui.Image? pictureOf(RomFile rom) => _pictures[rom.path];

  void useCore(String? path) {
    session.corePath = path;
    for (final preview in _previews) {
      preview.corePath = path;
    }
    _startPreviews();
  }

  void setRoms(List<RomFile> roms, {RomFile? lastPlayed}) {
    if (_disposed) return;
    final paths = roms.map((r) => r.path).toSet();
    _roms = List.of(roms);
    if (lastPlayed != null) _visited.add(lastPlayed.path);
    _visited.addAll(
      roms
          .where(
            (rom) => [
              1,
              2,
              3,
              resumeSlot,
            ].any((slot) => File(statePath(rom, slot)).existsSync()),
          )
          .map((rom) => rom.path),
    );
    _visited.removeWhere((path) => !paths.contains(path));
    _previewStates.removeWhere((path, _) => !paths.contains(path));
    _failed.removeWhere((path) => !paths.contains(path));
    final playing = session.rom;
    if (playing != null && !paths.contains(playing.path)) session.stop();
    for (final path
        in _pictures.keys.where((p) => !paths.contains(p)).toList()) {
      _pictures.remove(path)?.dispose();
    }
    _startPreviews();
    unawaited(_loadPictures(roms));
  }

  void _startPreviews() {
    if (_disposed || session.corePath == null) return;
    _rotate();
    if (_unvisited.isNotEmpty) {
      _rotation ??= Timer.periodic(previewTurn, (_) => _rotate());
    }
  }

  List<RomFile> get _unvisited => _roms
      .where(
        (rom) => !_visited.contains(rom.path) && !_failed.contains(rom.path),
      )
      .toList();

  void _rotate() {
    if (_disposed) return;
    final candidates = _unvisited;
    if (candidates.isEmpty) {
      _rotation?.cancel();
      _rotation = null;
    }
    final count = candidates.length.clamp(0, _previews.length);
    final next = List.generate(
      count,
      (i) => candidates[(_next + i) % candidates.length],
    );
    _next = candidates.isEmpty ? 0 : (_next + count) % candidates.length;

    for (final preview in _previews) {
      if (preview.rom != null && !next.contains(preview.rom))
        _parkPreview(preview);
    }
    for (final rom in next) {
      if (sessionFor(rom) != null) continue;
      final preview = _previews.where((s) => s.rom == null).firstOrNull;
      if (preview == null) break;
      preview.play(rom);
      if (!preview.isRunning) {
        _failed.add(rom.path);
        continue;
      }
      final state = _previewStates[rom.path];
      if (state != null && !preview.loadState(state)) {
        _failed.add(rom.path);
        preview.unload();
      }
    }
    notifyListeners();
  }

  void _rememberPicture(EmulatorSession source) {
    final rom = source.rom;
    final frame = source.frame;
    if (rom == null || frame == null) return;
    _pictures.remove(rom.path)?.dispose();
    _pictures[rom.path] = frame.clone();
  }

  void _parkPreview(EmulatorSession preview) {
    final rom = preview.rom;
    if (rom == null) return;
    if (!_roms.contains(rom)) {
      preview.unload();
      return;
    }
    preview.pause();
    final state = preview.saveState();
    if (state == null) {
      _failed.add(rom.path);
    } else {
      _previewStates[rom.path] = state;
    }
    _rememberPicture(preview);
    preview.unload();
  }

  bool _parkPlaying() {
    final rom = session.rom;
    if (rom == null || !session.isRunning) return true;
    session.pause();
    final state = session.saveState();
    if (state == null || !_saveResume(rom, state)) return false;
    _rememberPicture(session);
    final image = _pictures[rom.path]?.clone();
    final core = session.corePath;
    if (image != null && core != null) {
      unawaited(
        RomPortraits()
            .save(rom, image)
            .catchError((Object error) {
              if (!_disposed) session.log('could not save picture: $error');
            })
            .whenComplete(image.dispose),
      );
    }
    session.unload();
    return true;
  }

  bool _saveResume(RomFile rom, Uint8List state) {
    try {
      final path = statePath(rom, resumeSlot);
      File('$path.tmp')
        ..writeAsBytesSync(state, flush: true)
        ..renameSync(path);
      return true;
    } on FileSystemException catch (error) {
      session.log('could not preserve ${rom.title}: $error');
      return false;
    }
  }

  Future<void> play(RomFile rom) async {
    if (_disposed) return;
    if (session.rom == rom) {
      session.resume();
      return;
    }
    if (!_parkPlaying()) return;
    final preview = sessionFor(rom);
    if (preview != null) _parkPreview(preview);
    final saved = File(statePath(rom, resumeSlot));
    Uint8List? state;
    try {
      state = saved.existsSync()
          ? saved.readAsBytesSync()
          : _previewStates[rom.path];
    } on FileSystemException catch (error) {
      session.log('could not read ${rom.title} resume state: $error');
      _rotate();
      return;
    }
    session.play(rom);
    if (!session.isRunning) {
      _rotate();
      return;
    }
    _visited.add(rom.path);
    if (state != null && !session.loadState(state)) {
      session.unload();
      session.log('could not restore ${rom.title}');
      _rotate();
      notifyListeners();
      return;
    }
    _previewStates.remove(rom.path);
    final initial = session.saveState();
    if (initial != null) _saveResume(rom, initial);
    _rotate();
    notifyListeners();
  }

  Future<void> _loadPictures(List<RomFile> roms) async {
    final core = session.corePath;
    if (core == null) return;
    final portraits = RomPortraits();
    for (final rom in roms) {
      if (_disposed || _pictures.containsKey(rom.path)) continue;
      ui.Image? image;
      try {
        image = await portraits.load(rom);
      } on Object {
        continue;
      }
      if (image == null) continue;
      if (_disposed ||
          !_roms.contains(rom) ||
          _pictures.containsKey(rom.path)) {
        image.dispose();
        continue;
      }
      _pictures[rom.path] = image;
      notifyListeners();
    }
  }

  static String statePath(RomFile rom, int slot) => '${rom.path}.state$slot';

  void stop() {
    if (!_parkPlaying()) return;
    session.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _rotation?.cancel();
    _parkPlaying();
    _disposed = true;
    session
      ..removeListener(notifyListeners)
      ..dispose();
    for (final preview in _previews) {
      preview.dispose();
    }
    for (final image in _pictures.values) {
      image.dispose();
    }
    _pictures.clear();
    _previewStates.clear();
    super.dispose();
  }
}
