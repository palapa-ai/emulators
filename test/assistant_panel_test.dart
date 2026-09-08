import 'dart:io';

import 'package:emulator_palapa/emulator_palapa.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Assistant extends EmulatorAssistant {
  final questions = <String>[];

  @override
  Future<AssistantReply> ask(
    String question,
    EmulatorAssistantContext context,
  ) async {
    questions.add(question);
    return const AssistantReply(answer: 'Ready to help.');
  }
}

class _SuggestionSkin extends EmulatorSkin {
  final prompts = <String, ({EmulatorIcon? icon, bool labelled})>{};

  @override
  Widget button(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    EmulatorIcon? icon,
    VoidCallback? onSecondaryTap,
    bool labelled = false,
  }) {
    prompts[label] = (icon: icon, labelled: labelled);
    return GestureDetector(onTap: onTap, child: Text(label));
  }
}

void main() {
  testWidgets('welcome prompts use host buttons and send their original text', (
    tester,
  ) async {
    final temp = Directory.systemTemp.createTempSync('emulator-assistant-');
    final assistant = _Assistant();
    final model = EmulatorViewModel(
      libraryRoot: temp.path,
      corePath: '${temp.path}/missing-core',
    )..assistant = assistant;
    final skin = _SuggestionSkin();
    addTearDown(() {
      model.dispose();
      temp.deleteSync(recursive: true);
    });

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xff000000),
        builder: (_, _) => EmulatorTheme(
          skin: skin,
          child: AssistantPanel(viewModel: model),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Try asking:'), findsOneWidget);
    expect(skin.prompts.keys, [
      'make chun li fat',
      'frame generate to 60fps',
      'replace yoshi with wario',
    ]);
    expect(
      skin.prompts.values.every(
        (value) => value.labelled && value.icon == EmulatorIcon.controller,
      ),
      isTrue,
    );
    expect(
      tester.getTopLeft(find.text('Try asking:')).dy,
      lessThan(tester.getSize(find.byType(AssistantPanel)).height / 2),
    );
    expect(assistant.questions, isEmpty);

    await tester.tap(find.text('replace yoshi with wario'));
    await tester.pumpAndSettle();

    expect(assistant.questions, ['replace yoshi with wario']);
    expect(find.text('> replace yoshi with wario'), findsOneWidget);
    expect(find.text('Ready to help.'), findsOneWidget);
    expect(find.text('Try asking:'), findsNothing);
  });
}
