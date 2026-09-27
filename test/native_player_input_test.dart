import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native joypad ports stay independent for individual and bitmask reads',
    () async {
      final temporary = await Directory.systemTemp.createTemp('snes-input-');
      addTearDown(() => temporary.delete(recursive: true));
      final native =
          '${Directory.current.path}/macos/emulator_palapa/Sources/emulators_host';
      final source = File('${temporary.path}/test.c');
      await source.writeAsString('''#include "${native}/libretro_host.c"
#include <assert.h>
int main(void) {
  EmuSession session = {0};
  active = &session;
  emu_set_button(&session, EMU_BUTTON_A, 1);
  emu_set_player_button(&session, 1, EMU_BUTTON_B, 1);
  assert(cb_input_state(0, RETRO_DEVICE_JOYPAD, 0, EMU_BUTTON_A) == 1);
  assert(cb_input_state(1, RETRO_DEVICE_JOYPAD, 0, EMU_BUTTON_A) == 0);
  assert(cb_input_state(1, RETRO_DEVICE_JOYPAD, 0, EMU_BUTTON_B) == 1);
  assert(cb_input_state(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_MASK) == (1 << EMU_BUTTON_A));
  assert(cb_input_state(1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_MASK) == (1 << EMU_BUTTON_B));
  emu_set_player_button(&session, 1, EMU_BUTTON_B, 0);
  assert(cb_input_state(1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_MASK) == 0);
  emu_set_player_button(&session, 2, EMU_BUTTON_B, 1);
  emu_set_player_button(&session, -1, EMU_BUTTON_B, 1);
  assert(cb_input_state(2, RETRO_DEVICE_JOYPAD, 0, EMU_BUTTON_B) == 0);
  assert(cb_input_state(0, RETRO_DEVICE_JOYPAD, 0, EMU_BUTTON_A) == 1);
  return 0;
}
''');
      final binary = '${temporary.path}/probe';
      final build = await Process.run('xcrun', [
        'clang',
        '-O2',
        '-I$native/include',
        source.path,
        '-framework',
        'AudioToolbox',
        '-o',
        binary,
      ]);
      expect(build.exitCode, 0, reason: '${build.stderr}');
      final result = await Process.run(binary, []);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    },
    skip: !Platform.isMacOS,
  );
}
