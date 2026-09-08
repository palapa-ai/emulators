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
          _slot(context, skin, target, slot),
        ],
      ],
    );
  }

  Widget _slot(
    BuildContext context,
    EmulatorSkin skin,
    RomFile? target,
    int slot,
  ) {
    final occupied = target != null && viewModel.hasState(target, slot);
    final enabled = target != null && (saving || occupied);
    final label = '${saving ? 'Save' : 'Load'} slot $slot';
    final color = occupied
        ? skin.accent(context)
        : skin.textStyle(context, EmulatorTextRole.caption).color;
    return skin.hint(
      context,
      label,
      Semantics(
        label: label,
        button: true,
        enabled: enabled,
        selected: occupied,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: !enabled
                ? null
                : () => saving
                      ? viewModel.saveState(slot)
                      : viewModel.loadState(slot, from: rom),
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: occupied ? skin.accent(context) : skin.line(context),
                ),
              ),
              child: Text(
                '$slot',
                style: skin
                    .textStyle(context, EmulatorTextRole.caption)
                    .copyWith(color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
