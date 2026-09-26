import 'package:flutter/widgets.dart';

import '../controller_pairing.dart';
import '../player_controls.dart';
import 'emulator_glyph.dart';
import 'emulator_skin.dart';
import 'emulator_view_model.dart';

/// The demo's controller status and live input ticker, shared by every host.
class ControlsView extends StatelessWidget {
  const ControlsView({
    required this.viewModel,
    this.skin,
    this.showTrainingData = true,
    this.showPairing = true,
    this.onPairController,
    this.onDriverChanged,
    this.playerDetails,
    super.key,
  });

  final EmulatorViewModel viewModel;
  final EmulatorSkin? skin;
  final bool showTrainingData;
  final bool showPairing;
  final VoidCallback? onPairController;
  final ValueChanged<EmulatorPlayer>? onDriverChanged;
  final Widget Function(EmulatorPlayer)? playerDetails;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) =>
        _content(context, skin ?? EmulatorTheme.of(context)),
  );

  Widget _content(BuildContext context, EmulatorSkin skin) {
    return skin.panel(
      context,
      title: '',
      trailing: [
        if (showTrainingData)
          skin.button(
            context,
            label: viewModel.sharesTrainingData
                ? 'sharing training data'
                : 'not sharing training data',
            icon: viewModel.sharesTrainingData ? .training : .trainingOff,
            labelled: true,
            onTap: viewModel.toggleTrainingData,
          ),
        if (showPairing && viewModel.padName == null &&
            (onPairController != null || ControllerPairing.canOpen))
          skin.button(
            context,
            label: 'Connect controller',
            icon: .controller,
            labelled: true,
            onTap: onPairController ?? ControllerPairing.open,
          ),
      ],
      child: Column(
        crossAxisAlignment: .stretch,
        mainAxisSize: .min,
        children: [
          for (final player in EmulatorPlayer.values) ...[
            _ControllerLine(
              skin: skin,
              label: viewModel.controlsFor(player).label,
              name: viewModel.padNameFor(player),
              presses: viewModel
                  .controlsFor(player)
                  .history
                  .map((b) => b.label)
                  .toList(),
              onToggle: onDriverChanged == null
                  ? null
                  : () => onDriverChanged?.call(player),
            ),
            if (playerDetails case final details?) details(player),
            if (player != EmulatorPlayer.values.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ControllerLine extends StatelessWidget {
  const _ControllerLine({
    required this.skin,
    required this.label,
    this.onToggle,
    required this.presses,
    this.name,
  });

  final EmulatorSkin skin;
  final String label;
  final VoidCallback? onToggle;
  final String? name;
  final List<String> presses;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: Row(
      children: [
        const EmulatorGlyph(EmulatorIcon.controller, size: 13),
        const SizedBox(width: 6),
        if (onToggle case final toggle?)
          skin.button(
            context,
            label: label,
            onTap: toggle,
            preserveLabelCase: true,
          )
        else
          skin.text(context, label, role: .caption),
        if (name case final value?) ...[
          const SizedBox(width: 8),
          Flexible(
            child: skin.text(context, value, role: .caption, maxLines: 1),
          ),
        ],
        const SizedBox(width: 12),
        Expanded(
          child: presses.isEmpty
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: skin.text(
                    context,
                    name == null ? 'No input' : 'Connected',
                    role: .caption,
                  ),
                )
              : ListView.separated(
                  scrollDirection: .horizontal,
                  reverse: true,
                  itemCount: presses.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Center(
                    child: skin.text(
                      context,
                      presses[presses.length - 1 - i],
                      role: i == 0 ? .heading : .caption,
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}
