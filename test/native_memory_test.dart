import 'package:emulator_palapa/src/native_memory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'allocates and releases UTF-8 strings through the platform C runtime',
    () {
      final pointer = 'save slot 雪 🎮'.toNative();
      try {
        expect(pointer.toDart(), 'save slot 雪 🎮');
      } finally {
        release(pointer);
      }
    },
  );
}
