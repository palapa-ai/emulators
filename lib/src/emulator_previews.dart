import 'emulator_session.dart';
import 'rom_file.dart';

class EmulatorPreviews {
  final _entries = <String, _PreviewEntry>{};
  bool _disposed = false;

  EmulatorSession? sessionFor(RomFile rom) => _entries[rom.path]?.session;

  EmulatorSession? retain(RomFile rom, String? corePath) {
    if (_disposed || corePath == null) return null;

    final entry = _entries.putIfAbsent(rom.path, () {
      final session = createSession(corePath)..play(rom);
      return _PreviewEntry(session);
    });
    entry.readers++;
    return entry.session;
  }

  EmulatorSession createSession(String corePath) =>
      EmulatorSession(corePath: corePath, preview: true);

  void release(RomFile rom, EmulatorSession? session) {
    final entry = _entries[rom.path];
    if (entry == null || !identical(entry.session, session)) return;
    if (--entry.readers > 0) return;

    _entries.remove(rom.path);
    entry.session.dispose();
  }

  void stop() {
    final sessions = _entries.values.map((entry) => entry.session).toList();
    _entries.clear();
    sessions.forEach((session) => session.dispose());
  }

  void dispose() {
    _disposed = true;
    stop();
  }
}

class _PreviewEntry {
  _PreviewEntry(this.session);

  final EmulatorSession session;
  int readers = 0;
}
