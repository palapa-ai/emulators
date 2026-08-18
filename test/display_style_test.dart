import 'package:emulators/emulators.dart';
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

  test('styles only ever darken', () {
    for (final style in DisplayStyle.values) {
      for (final fx in const [0.0, 0.4, 0.9]) {
        for (final fy in const [0.0, 0.4, 0.9]) {
          final c = style.sample(fx, fy, 0);
          expect(c.r, lessThanOrEqualTo(1.0));
          expect(c.g, lessThanOrEqualTo(1.0));
          expect(c.b, lessThanOrEqualTo(1.0));
        }
      }
    }
  });

  test('a scanline darkens the bottom of the emulated pixel', () {
    const style = DisplayStyle.trinitron;
    final lit = style.sample(0.5, 0.1, 0);
    final dark = style.sample(0.5, 0.95, 0);

    expect(dark.g, lessThan(lit.g));
  });

  test('the phosphor triad splits the pixel into three bands', () {
    const style = DisplayStyle.trinitron;

    expect(style.sample(0.1, 0.1, 0).r, greaterThan(style.sample(0.5, 0.1, 0).r));
  });
}
