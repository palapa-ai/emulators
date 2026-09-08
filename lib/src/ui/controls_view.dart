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
      child: Column(
        crossAxisAlignment: .stretch,
        mainAxisSize: .min,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: .center,
            children: [
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
              if (viewModel.padName case final pad?)
                Row(
                  mainAxisSize: .min,
                  children: [
                    const EmulatorGlyph(EmulatorIcon.controller, size: 13),
                    const SizedBox(width: 6),
                    skin.text(context, pad, role: .caption),
                  ],
                )
              else if (onPairController != null || ControllerPairing.canOpen)
                skin.button(
                  context,
                  label: 'Connect controller',
                  icon: .controller,
                  labelled: true,
                  onTap: onPairController ?? ControllerPairing.open,
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 24,
            child: Row(
              children: [
                skin.text(context, 'Controller #1', role: .caption),
                const SizedBox(width: 12),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: .horizontal,
                    reverse: true,
                    itemCount: presses.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Center(
                      child: skin.text(
                        context,
                        presses[presses.length - 1 - i].label,
                        role: i == 0 ? .heading : .caption,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
