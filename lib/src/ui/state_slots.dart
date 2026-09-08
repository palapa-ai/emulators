import 'dart:async';

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
          _StateSlot(
            key: ValueKey((viewModel, target?.path, saving, slot)),
            viewModel: viewModel,
            rom: rom,
            target: target,
            saving: saving,
            slot: slot,
          ),
        ],
      ],
    );
  }
}

class _StateSlot extends StatefulWidget {
  const _StateSlot({
    required this.viewModel,
    required this.rom,
    required this.target,
    required this.saving,
    required this.slot,
    super.key,
  });

  final EmulatorViewModel viewModel;
  final RomFile? rom;
  final RomFile? target;
  final bool saving;
  final int slot;

  @override
  State<_StateSlot> createState() => _StateSlotState();
}

class _StateSlotState extends State<_StateSlot> {
  static const _numerals = ['①', '②', '③'];
  Timer? _restore;
  bool _pending = false;
  bool _confirmed = false;

  @override
  void dispose() {
    _restore?.cancel();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_pending) return;
    _pending = true;
    _restore?.cancel();
    if (_confirmed) setState(() => _confirmed = false);

    final succeeded = widget.saving
        ? await widget.viewModel.saveState(widget.slot)
        : await widget.viewModel.loadState(widget.slot, from: widget.rom);
    _pending = false;
    if (!mounted || !succeeded) return;

    setState(() => _confirmed = true);
    _restore = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _confirmed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = EmulatorTheme.of(context);
    final target = widget.target;
    final occupied =
        target != null && widget.viewModel.hasState(target, widget.slot);

    return Semantics(
      button: true,
      label: '${widget.saving ? 'Save' : 'Load'} slot ${widget.slot}',
      value: _confirmed ? (widget.saving ? 'Saved' : 'Loaded') : null,
      liveRegion: _confirmed,
      child: GestureDetector(
        onTap: _activate,
        child: ExcludeSemantics(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: _confirmed ? 0 : 1,
                child: Text(
                  _numerals[widget.slot - 1],
                  style: TextStyle(
                    fontSize: 20,
                    color: occupied
                        ? skin.accent(context)
                        : skin
                              .textStyle(context, EmulatorTextRole.caption)
                              .color,
                  ),
                ),
              ),
              if (_confirmed)
                Positioned.fill(
                  child: Center(
                    child: EmulatorGlyph(
                      EmulatorIcon.check,
                      size: 16,
                      color: skin.accent(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ).clickable,
    );
  }
}
