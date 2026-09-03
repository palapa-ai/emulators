import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../emulator_button.dart';
import 'emulator_screen.dart';
import 'emulator_skin.dart';
import 'emulator_view_model.dart';

/// What the keyboard does, and what the pad is doing right now.
///
/// The bindings were only ever inside the key handler, so the one question a
/// player actually asks — which key is B? — had nowhere to be answered.
class ControlsView extends StatelessWidget {
  const ControlsView({required this.viewModel, super.key});

  final EmulatorViewModel viewModel;

  static final _order = [
    EmulatorButton.up,
    EmulatorButton.down,
    EmulatorButton.left,
    EmulatorButton.right,
    EmulatorButton.a,
    EmulatorButton.b,
    EmulatorButton.x,
    EmulatorButton.y,
    EmulatorButton.l,
    EmulatorButton.r,
    EmulatorButton.start,
    EmulatorButton.select,
  ];

  /// The key that stands for a button, named the way a keycap is.
  static String _keyFor(EmulatorButton button) {
    for (final entry in keyBindings.entries) {
      if (entry.value != button) continue;
      return switch (entry.key) {
        LogicalKeyboardKey.arrowUp => '↑',
        LogicalKeyboardKey.arrowDown => '↓',
        LogicalKeyboardKey.arrowLeft => '←',
        LogicalKeyboardKey.arrowRight => '→',
        LogicalKeyboardKey.enter => '⏎',
        LogicalKeyboardKey.shiftRight => '⇧ right',
        final key => key.keyLabel,
      };
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final skin = EmulatorTheme.of(context);

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final held = viewModel.heldMask;

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            for (final button in _order)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    // A held button lights, so the panel doubles as the
                    // answer to "is this pad even reaching the game".
                    skin.text(
                      context,
                      button.label,
                      role: held & (1 << button.id) != 0
                          ? EmulatorTextRole.body
                          : EmulatorTextRole.caption,
                    ),
                    const Spacer(),
                    skin.text(
                      context,
                      _keyFor(button),
                      role: EmulatorTextRole.caption,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
