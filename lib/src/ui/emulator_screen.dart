import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../emulator_button.dart';
import '../emulator_session.dart';
import 'emulator_skin.dart';
import 'emulator_view_model.dart';
import 'style_overlay.dart';
import 'vhs_view.dart';

final _keyBindings = <LogicalKeyboardKey, EmulatorButton>{
  .arrowUp: .up,
  .arrowDown: .down,
  .arrowLeft: .left,
  .arrowRight: .right,
  .keyZ: .b,
  .keyX: .a,
  .keyA: .y,
  .keyS: .x,
  .keyQ: .l,
  .keyW: .r,
  .enter: .start,
  .shiftRight: .select,
};

/// The whole feature: the running game over the shelf it came from.
///
/// Everything it draws goes through [EmulatorSkin], so a host restyles it by
/// wrapping this in an [EmulatorTheme] rather than rebuilding the screen. Pass
/// a [viewModel] to drive it from outside — adding cartridges, say — otherwise
/// it owns one.
class EmulatorScreen extends StatefulWidget {
  const EmulatorScreen({
    this.viewModel,
    this.corePath,
    this.libraryRoot,
    this.autoPlay = false,
    this.onPairController,
    this.showShelf = true,
    this.transportLeading,
    super.key,
  });

  /// Sits at the left of the transport row — for controls only the host can
  /// provide, like save slots that need somewhere to write.
  final Widget? transportLeading;

  /// Hosts that give the collection its own place on screen turn this off.
  final bool showShelf;

  /// Shown as a button while no pad is attached — pairing is the host's
  /// business, since only it knows how this platform opens Bluetooth.
  final VoidCallback? onPairController;

  final EmulatorViewModel? viewModel;
  final String? corePath;
  final String? libraryRoot;
  final bool autoPlay;

  @override
  State<EmulatorScreen> createState() => _EmulatorScreenState();
}

class _EmulatorScreenState extends State<EmulatorScreen> {
  EmulatorViewModel? _owned;

  EmulatorViewModel get _viewModel =>
      widget.viewModel ??
      (_owned ??= EmulatorViewModel(
        corePath: widget.corePath,
        libraryRoot: widget.libraryRoot,
        autoPlay: widget.autoPlay,
      ));

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    final button = _keyBindings[event.logicalKey];
    if (button == null) return .ignored;
    if (event is KeyRepeatEvent) return .handled;

    _viewModel.press(button, pressed: event is KeyDownEvent);
    return .handled;
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    final skin = EmulatorTheme.of(context);

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ColoredBox(
        color: skin.background(context),
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) => Column(
            crossAxisAlignment: .stretch,
            children: [
              Expanded(
                child: _Stage(
                  viewModel: viewModel,
                  skin: skin,
                  onPairController: widget.onPairController,
                  transportLeading: widget.transportLeading,
                ),
              ),
              if (widget.showShelf) ...[
                const SizedBox(height: 16),
                _Shelf(viewModel: viewModel, skin: skin),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.viewModel,
    required this.skin,
    this.onPairController,
    this.transportLeading,
  });

  final EmulatorViewModel viewModel;
  final EmulatorSkin skin;
  final VoidCallback? onPairController;
  final Widget? transportLeading;

  @override
  Widget build(BuildContext context) {
    final rom = viewModel.playing;
    if (rom == null) return _Idle(viewModel: viewModel, skin: skin);

    final session = viewModel.session;

    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: skin.screen(context),
              border: Border.all(color: skin.line(context)),
            ),
            child: SizedBox.expand(
              child: switch (session.frame) {
                  null => const SizedBox.expand(),
                  final frame when viewModel.style?.shader ?? false =>
                    VhsView(frame: frame),
                  final frame => StyleOverlay(
                    style: viewModel.style,
                    sourceWidth: frame.width,
                    sourceHeight: frame.height,
                    child: RawImage(image: frame, fit: .fill),
                  ),
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (transportLeading != null) transportLeading ?? const SizedBox(),
            const Spacer(),
            if (onPairController != null)
              skin.button(
                context,
                label: viewModel.gamepadName ?? 'Pair controller',
                icon: .controller,
                onTap: onPairController ?? () {},
              ),
            if (onPairController != null) const SizedBox(width: 8),
            skin.button(
              context,
              label: viewModel.style?.label ?? 'Raw',
              icon: .display,
              onTap: viewModel.cycleStyle,
            ),
            const SizedBox(width: 8),
            skin.button(
              context,
              label: viewModel.isMuted ? 'Unmute' : 'Mute',
              icon: viewModel.isMuted ? .muted : .sound,
              onTap: viewModel.toggleMuted,
            ),
            const SizedBox(width: 8),
            skin.button(
              context,
              label: viewModel.speed.label,
              icon: .speed,
              onTap: viewModel.cycleSpeed,
            ),
            const SizedBox(width: 8),
            skin.button(
              context,
              label: 'Reset',
              icon: .reset,
              onTap: viewModel.reset,
            ),
            const SizedBox(width: 8),
            skin.button(
              context,
              label: viewModel.isPaused ? 'Resume' : 'Pause',
              icon: viewModel.isPaused ? .play : .pause,
              onTap: viewModel.togglePause,
            ),
          ],
        ),
      ],
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle({required this.viewModel, required this.skin});

  final EmulatorViewModel viewModel;
  final EmulatorSkin skin;

  @override
  Widget build(BuildContext context) {
    final message = switch (viewModel.status) {
      SessionStatus.unavailable =>
        'No emulator core is bundled for this platform',
      SessionStatus.failed =>
        viewModel.session.error ?? 'That cartridge would not load',
      _ => 'Pick a cartridge below',
    };

    return Center(child: skin.text(context, message, role: .caption));
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.viewModel, required this.skin});

  final EmulatorViewModel viewModel;
  final EmulatorSkin skin;

  @override
  Widget build(BuildContext context) {
    final roms = viewModel.roms;

    return skin.panel(
      context,
      title: 'Collection',
      trailing: [skin.text(context, '${roms.length}', role: .caption)],
      child: SizedBox(
        height: 104,
        child: roms.isEmpty
            ? Center(
                child: skin.text(
                  context,
                  'No cartridges yet',
                  role: .caption,
                ),
              )
            : ListView.separated(
                scrollDirection: .horizontal,
                itemCount: roms.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => skin.cartridge(
                  context,
                  title: roms[i].title,
                  subtitle: roms[i].sizeLabel,
                  playing: roms[i] == viewModel.playing,
                  onTap: () => viewModel.play(roms[i]),
                  onRemove: () => viewModel.remove(roms[i]),
                ),
              ),
      ),
    );
  }
}
