import 'package:emulator_palapa/emulator_palapa.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every style has a label', () {
    for (final style in DisplayStyle.values) {
      expect(style.label, isNotEmpty);
    }
  });

  test('next and previous wrap around', () {
    expect(DisplayStyle.values.last.next, DisplayStyle.values.first);
    expect(DisplayStyle.values.first.previous, DisplayStyle.values.last);
  });
}
