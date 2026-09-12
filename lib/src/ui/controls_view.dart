import 'package:flutter/widgets.dart';

import '../controller_pairing.dart';
import 'emulator_glyph.dart';
import 'emulator_skin.dart';
import 'emulator_view_model.dart';

/// The demo's controller status and live input ticker, shared by every host.
class ControlsView extends StatelessWidget {
  const ControlsView({
    required this.viewModel,
    this.skin,
    this.showTrainingData = true,
    this.onPairController,
    super.key,
  });

  final EmulatorViewModel viewModel;
  final EmulatorSkin? skin;
  final bool showTrainingData;
  final VoidCallback? onPairController;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) =>
        _content(context, skin ?? EmulatorTheme.of(context)),
  );

  Widget _content(BuildContext context, EmulatorSkin skin) {
    final presses = viewModel.padLog;
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
        if (viewModel.padName == null &&
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
          _ControllerLine(
            skin: skin,
            number: 1,
            name: viewModel.padName,
            presses: presses.map((press) => press.label).toList(),
          ),
          const SizedBox(height: 8),
          _ControllerLine(skin: skin, number: 2, presses: const []),
        ],
      ),
    );
  }
}

class _ControllerLine extends StatelessWidget {
  const _ControllerLine({
    required this.skin,
    required this.number,
    required this.presses,
    this.name,
  });

  final EmulatorSkin skin;
  final int number;
  final String? name;
  final List<String> presses;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    child: Row(
      children: [
        const EmulatorGlyph(EmulatorIcon.controller, size: 13),
        const SizedBox(width: 6),
        skin.text(context, 'Controller #$number', role: .caption),
        if (name case final value?) ...[
          const SizedBox(width: 8),
          skin.text(context, value, role: .caption),
        ],
        const SizedBox(width: 12),
        Expanded(
          child: presses.isEmpty
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: skin.text(context, 'Not connected', role: .caption),
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
