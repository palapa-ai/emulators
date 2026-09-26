import 'dart:io';
import 'dart:typed_data';
import 'package:emulator_palapa/emulator_palapa.dart';
import 'package:flutter_test/flutter_test.dart';

class _Session extends EmulatorSession {
  @override
  RomFile? rom;
  Uint8List? bytes = Uint8List.fromList([1, 2, 3]);
  @override
  Uint8List? saveState() => bytes;
}

class _Console extends EmulatorViewModel {
  _Console(this.savedSession) : super(corePath: '/missing/core');
  final EmulatorSession savedSession;
  @override
  EmulatorSession get session => savedSession;
  @override
  Future<void> refresh() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('save feedback reports disk completion and capture failure', () async {
    final directory = Directory.systemTemp.createTempSync('emulator-save-');
    final rom = RomFile(
      path: '${directory.path}/game.smc',
      title: 'Game',
      sizeBytes: 1,
    );
    final session = _Session()..rom = rom;
    final console = _Console(session);
    addTearDown(() {
      console.dispose();
      session.dispose();
      directory.deleteSync(recursive: true);
    });
    final saving = console.saveState(1);
    expect(console.saveFeedback[(rom.path, 1)], SaveFeedback.saving);
    await saving;
    expect(File('${rom.path}.state1').readAsBytesSync(), [1, 2, 3]);
    expect(console.saveFeedback[(rom.path, 1)], SaveFeedback.saved);
    session.bytes = null;
    await console.saveState(2);
    expect(console.saveFeedback[(rom.path, 2)], SaveFeedback.failed);
    expect(File('${rom.path}.state2').existsSync(), isFalse);
  });
}
