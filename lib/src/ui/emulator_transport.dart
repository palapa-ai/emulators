import 'package:flutter/widgets.dart';

import '../controller_pairing.dart';
import 'emulator_glyph.dart';
import 'emulator_skin.dart';
import 'emulator_view_model.dart';
import 'state_slots.dart';

/// The emulator's existing playback, display and save controls, for hosts
/// that give them their own place outside the screen.
class EmulatorTransport extends StatelessWidget {
  const EmulatorTransport({
    required this.viewModel,
    this.showTrainingData = true,
    this.showPixelShape = false,
    this.onPairController,
    this.onFullscreen,
    this.leading,
    this.trailing,
    super.key,
  });

  final EmulatorViewModel viewModel;
  final bool showTrainingData;
  final bool showPixelShape;
  final VoidCallback? onPairController;
  final ValueChanged<bool>? onFullscreen;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) => _controls(context),
  );

  Widget _controls(BuildContext context) {
    final skin = EmulatorTheme.of(context);
    final saves = [
      if (viewModel.playing != null) ...[
        StateSlots(viewModel: viewModel),
        StateSlots(viewModel: viewModel, saving: false),
      ],
      if (leading case final leading?) leading,
    ];
    final playback = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (onPairController != null ||
            (viewModel.gamepadName == null && ControllerPairing.canOpen)) ...[
          skin.button(
            context,
            label: viewModel.gamepadName ?? 'Connect controller',
            icon: .controller,
            onTap: onPairController ?? ControllerPairing.open,
          ),
        ],
        if (showTrainingData) ...[
          skin.button(
            context,
            label: viewModel.sharesTrainingData
                ? 'sharing training data'
                : 'not sharing training data',
            icon: viewModel.sharesTrainingData ? .training : .trainingOff,
            onTap: viewModel.toggleTrainingData,
          ),
        ],
        skin.button(
          context,
          label: viewModel.style?.label ?? 'Raw',
          icon: viewModel.style.icon,
          onTap: viewModel.cycleStyle,
          onSecondaryTap: () => viewModel.cycleStyle(reverse: true),
        ),
        skin.button(
          context,
          label: viewModel.isMuted ? 'Unmute' : 'Mute',
          icon: viewModel.isMuted ? .muted : .sound,
          onTap: viewModel.toggleMuted,
        ),
        if (showPixelShape) ...[
          skin.button(
            context,
            label: viewModel.squarePixels ? '1:1' : '4:3',
            onTap: viewModel.togglePixelShape,
          ),
        ],
        skin.button(
          context,
          label: viewModel.speed.label,
          onTap: viewModel.cycleSpeed,
          onSecondaryTap: () => viewModel.cycleSpeed(reverse: true),
        ),
        // Beside the speed it governs: at 1x that button is a play triangle,
        // and the two reading as a pair is the point.
        skin.button(
          context,
          label: viewModel.isPaused ? 'Resume' : 'Pause',
          icon: viewModel.isPaused ? .play : .pause,
          onTap: viewModel.togglePause,
        ),
        skin.button(
          context,
          label: 'Reset',
          icon: .reset,
          onTap: viewModel.reset,
        ),
        if (trailing != null) ...[trailing ?? const SizedBox()],
        skin.button(
          context,
          label: viewModel.fullscreen ? 'Leave fullscreen' : 'Fullscreen',
          icon: viewModel.fullscreen ? .fullscreenExit : .fullscreen,
          onTap: () {
            viewModel.toggleFullscreen();
            onFullscreen?.call(viewModel.fullscreen);
          },
        ),
      ],
    );
    if (saves.isEmpty)
      return Align(alignment: Alignment.centerRight, child: playback);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          flex: 2,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: saves,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(flex: 3, child: playback),
      ],
    );
  }
}
