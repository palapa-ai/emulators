import 'package:emulator_palapa/emulator_palapa.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'each player owns its input and switching drivers releases held buttons',
    () {
      final p1 = PlayerControls(.p1);
      final p2 = PlayerControls(.p2);
      addTearDown(p1.dispose);
      addTearDown(p2.dispose);
      p1.update(.human, 1 << EmulatorButton.a.id);
      expect(p2.held, 0);
      p1.assign(.ai);
      expect(p1.label, 'AI P1');
      expect(p1.held, 0);
      p1.update(.human, 1 << EmulatorButton.right.id);
      expect(p1.held, 0);
      p1.update(.ai, 1 << EmulatorButton.left.id);
      expect(p1.history, [EmulatorButton.left]);
      p1.assign(.human);
      expect(p1.held, 0);
      expect(p1.history, isEmpty);
      expect(p2.label, 'Human P2');
    },
  );
  test(
    'invalid ports never inherit P1 input and stopped sessions reject AI',
    () {
      final session = EmulatorSession();
      addTearDown(session.dispose);
      final before = session.inputRevision;
      session.assignPlayer(.p2, .ai);
      expect(session.inputRevision, greaterThan(before));
      expect(session.applyAi(.p2, 1, revision: before), isFalse);
      expect(session.applyAi(.p2, 1, revision: session.inputRevision), isFalse);
      session.controlsFor(.p2).update(.ai, 1);
      session.stop();
      expect(session.controlsFor(.p2).held, 0);
    },
  );
  test('history records new presses only and is bounded', () {
    final controls = PlayerControls(.p2);
    addTearDown(controls.dispose);
    for (var i = 0; i < 200; i++) {
      controls.update(.human, 1);
      controls.update(.human, 1);
      controls.release();
    }
    expect(controls.history.length, 120);
    expect(controls.held, 0);
  });
}
