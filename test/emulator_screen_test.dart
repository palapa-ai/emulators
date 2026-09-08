import 'dart:io';

import 'package:emulator_palapa/emulator_palapa.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _LoudSkin extends EmulatorSkin {
  const _LoudSkin();

  @override
  Widget text(
    BuildContext context,
    String value, {
    EmulatorTextRole role = EmulatorTextRole.body,
    int? maxLines,
  }) => Text('[$value]', textDirection: TextDirection.ltr);
}

Widget _wrap(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('emulators_test'));
  tearDown(() => temp.deleteSync(recursive: true));

  testWidgets('runs with no core and says so', (tester) async {
    await tester.pumpWidget(_wrap(EmulatorScreen(libraryRoot: temp.path)));
    await tester.pumpAndSettle();

    expect(find.text('Pick a game'), findsOneWidget);
    expect(find.text('Collection'), findsOneWidget);
    expect(find.text('No cartridges yet'), findsOneWidget);
  });

  testWidgets('shelves the cartridges it finds', (tester) async {
    Directory('${temp.path}${Platform.pathSeparator}roms')
      ..createSync(recursive: true)
      ..childFile('Star Fox (U) (V1.2) [!].smc').writeAsBytesSync([0, 1, 2]);

    final model = EmulatorViewModel(
      libraryRoot: temp.path,
    );
    await tester.runAsync(model.refresh);
    await tester.pumpWidget(_wrap(EmulatorScreen(viewModel: model)));
    await tester.pumpAndSettle();

    expect(find.text('Star Fox'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });

  testWidgets('a host skin replaces how the package draws', (tester) async {
    await tester.pumpWidget(
      _wrap(
        EmulatorTheme(
          skin: const _LoudSkin(),
          child: EmulatorScreen(libraryRoot: temp.path),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('[Collection]'), findsOneWidget);
    expect(find.text('Collection'), findsNothing);
  });
}

extension on Directory {
  File childFile(String name) => File('$path${Platform.pathSeparator}$name');
}
