import 'dart:typed_data';

import 'package:emulator_palapa/src/ui/memory_dump.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('narrow memory rows scroll horizontally at text scale $scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Center(
              child: SizedBox(
                width: 280,
                height: 200,
                child: MemoryDump(
                  current: Uint8List.fromList(
                    List.generate(4096, (i) => 65 + i % 26),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final horizontal = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      );
      final state = tester.state<ScrollableState>(horizontal);
      expect(state.position.maxScrollExtent, greaterThan(0));
      await tester.drag(horizontal, const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(state.position.pixels, greaterThan(0));
      await tester.dragFrom(const Offset(400, 300), const Offset(0, -150));
      await tester.pumpAndSettle();
      final vertical = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      expect(
        tester.state<ScrollableState>(vertical).position.pixels,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
