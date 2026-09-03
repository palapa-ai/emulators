import 'package:flutter/widgets.dart';

import '../rom_file.dart';
import 'emulator_glyph.dart';
import 'emulator_skin.dart';
import 'emulator_view_model.dart';

/// Three save slots and three load slots, beside the game they belong to.
///
/// A numbered slot that has something in it wears the accent; an empty one
/// stays quiet, so the row says what is there without a word of explanation.
class StateSlots extends StatelessWidget {
  const StateSlots({
    required this.viewModel,
    this.rom,
    this.saving = true,
    this.showIcon = true,
    super.key,
  });

  final EmulatorViewModel viewModel;

  /// The cartridge these slots belong to; the playing one when left out.
  final RomFile? rom;
  final bool saving;
  final bool showIcon;

  static const _numerals = ['①', '②', '③'];

  @override
  Widget build(BuildContext context) {
    final skin = EmulatorTheme.of(context);
    final target = rom ?? viewModel.playing;

    return Row(
      mainAxisSize: .min,
      children: [
        if (showIcon)
          EmulatorGlyph(
            saving ? EmulatorIcon.save : EmulatorIcon.load,
            size: 16,
          ),
        for (var slot = 1; slot <= EmulatorViewModel.slotCount; slot++) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => saving
                ? viewModel.saveState(slot)
                : viewModel.loadState(slot, from: rom),
            child: Text(
              _numerals[slot - 1],
              style: TextStyle(
                fontSize: 20,
                color: target != null && viewModel.hasState(target, slot)
                    ? skin.accent(context)
                    : skin.textStyle(context, EmulatorTextRole.caption).color,
              ),
            ),
          ).clickable,
        ],
      ],
    );
  }
}
