import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controller_pairing.dart';
import '../emulator_button.dart';
import '../emulator_session.dart';
import '../rom_file.dart';
import 'emulator_skin.dart';
import 'emulator_view_model.dart';
import 'state_slots.dart';
import 'style_shader_view.dart';

/// Which key stands for which button. Public because "what are the
/// controls" is a question the screen has to be able to answer.
final keyBindings = <LogicalKeyboardKey, EmulatorButton>{
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
    this.showPixelShape = false,
    this.showTrainingData = true,
    this.showFullscreen = true,
    this.transportLeading,
    this.transportTrailing,
    this.onFullscreen,
    super.key,
  });

  /// Told when the picture takes over the screen, so a host can put its own
  /// window into the matching state — the package cannot reach the platform.
  final ValueChanged<bool>? onFullscreen;

  /// Sits at the left of the transport row — for controls only the host can
  /// provide, like save slots that need somewhere to write.
  final Widget? transportLeading;

  /// Joins the right-hand cluster of transport buttons — for host controls
  /// that belong with them, like a fullscreen toggle.
  final Widget? transportTrailing;

  /// Hosts that give the collection its own place on screen turn this off.
  final bool showShelf;

  /// Offers the pixel-shape toggle. A workbench wants to compare the two; a
  /// host that has picked the television's shape should not ask again.
  final bool showPixelShape;

  /// A host that puts this toggle in its own chrome turns the transport's
  /// copy off rather than showing the player two of them.
  final bool showTrainingData;

  /// Hosts with a fullscreen header action hide the transport copy.
  final bool showFullscreen;

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
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is! KeyDownEvent || !_viewModel.fullscreen) return .ignored;
      _setFullscreen(false);
      return .handled;
    }

    final button = keyBindings[event.logicalKey];
    if (button == null) return .ignored;
    if (event is KeyRepeatEvent) return .handled;

    _viewModel.press(button, pressed: event is KeyDownEvent);
    return .handled;
  }

  void _setFullscreen(bool on) {
    if (_viewModel.fullscreen == on) return;
    _viewModel.toggleFullscreen();
    widget.onFullscreen?.call(on);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    final skin = EmulatorTheme.of(context);

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final stage = _Stage(
            viewModel: viewModel,
            skin: skin,
            immersive: viewModel.fullscreen,
            showPixelShape: widget.showPixelShape,
            showTrainingData: widget.showTrainingData,
            showFullscreen: widget.showFullscreen,
            onFullscreen: () => _setFullscreen(!viewModel.fullscreen),
            onPairController: widget.onPairController,
            transportLeading: viewModel.fullscreen
                ? null
                : widget.transportLeading,
            transportTrailing: viewModel.fullscreen
                ? null
                : widget.transportTrailing,
          );

          // Nothing but the picture: the shelf and the host's own chrome are
          // not drawn at all rather than covered up.
          if (viewModel.fullscreen) {
            return ColoredBox(color: const Color(0xff000000), child: stage);
          }

          return ColoredBox(
            color: skin.background(context),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                Expanded(child: stage),
                if (widget.showShelf) ...[
                  const SizedBox(height: 16),
                  EmulatorShelf(viewModel: viewModel, skin: skin),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.viewModel,
    required this.skin,
    required this.immersive,
    required this.onFullscreen,
    this.showPixelShape = false,
    this.showTrainingData = true,
    this.showFullscreen = true,
    this.onPairController,
    this.transportLeading,
    this.transportTrailing,
  });

  final EmulatorViewModel viewModel;
  final EmulatorSkin skin;
  final bool immersive;
  final bool showPixelShape;
  final bool showTrainingData;

  /// Hosts with a fullscreen header action hide the transport copy.
  final bool showFullscreen;
  final VoidCallback onFullscreen;
  final VoidCallback? onPairController;
  final Widget? transportLeading;
  final Widget? transportTrailing;

  @override
  Widget build(BuildContext context) {
    final rom = viewModel.playing;
    if (rom == null) return _Idle(viewModel: viewModel, skin: skin);

    final picture = _picture(context);
    final transport = _transport(context);

    // Filling the screen, the controls lie over the picture and leave when
    // the pointer settles, so nothing but the game is on screen while playing.
    if (immersive) {
      return _Immersive(picture: picture, transport: transport);
    }

    return Column(
      children: [
        Expanded(child: picture),
        const SizedBox(height: 8),
        transport,
      ],
    );
  }

  Widget _picture(BuildContext context) {
    final session = viewModel.session;

    return GestureDetector(
      key: const ValueKey('emulator-picture'),
      onTap: viewModel.togglePause,
      child: Container(
        decoration: BoxDecoration(
          color: skin.screen(context),
          border: immersive ? null : Border.all(color: skin.line(context)),
        ),
        // The picture is the only thing arriving at frame rate, so it
        // repaints on its own rather than with the rest of the screen.
        child: RepaintBoundary(
          child: ValueListenableBuilder<ui.Image?>(
            valueListenable: session.frames,
            // The stage fills whatever room it is given, but the picture
            // keeps the shape the console drew it in.
            builder: (context, frame, _) => Center(
              child: switch ((frame, viewModel.style)) {
                (null, _) => const SizedBox.expand(),
                (final frame?, final style?) => AspectRatio(
                  aspectRatio: viewModel.aspectFor(frame.width, frame.height),
                  child: StyleShaderView(frame: frame, style: style),
                ),
                (final frame?, null) => AspectRatio(
                  aspectRatio: viewModel.aspectFor(frame.width, frame.height),
                  child: RawImage(
                    image: frame,
                    fit: .fill,
                    filterQuality: .none,
                  ),
                ),
              },
            ),
          ),
        ),
      ),
    ).clickable;
  }

  Widget _transport(BuildContext context) {
    final controls = <Widget>[
      // The pad and the slots lead: they belong to the cartridge, while
      // everything to the right of the gap belongs to the picture.
      if (onPairController != null ||
          (viewModel.gamepadName == null && ControllerPairing.canOpen)) ...[
        skin.button(
          context,
          label: viewModel.gamepadName ?? 'Connect controller',
          icon: .controller,
          onTap: onPairController ?? ControllerPairing.open,
        ),
        const SizedBox(width: 16),
      ],
      if (viewModel.playing != null) ...[
        StateSlots(viewModel: viewModel),
        const SizedBox(width: 16),
        StateSlots(viewModel: viewModel, saving: false),
        const SizedBox(width: 16),
      ],
      if (transportLeading != null) transportLeading ?? const SizedBox(),
      if (showTrainingData) ...[
        skin.button(
          context,
          label: viewModel.sharesTrainingData
              ? 'sharing training data'
              : 'not sharing training data',
          icon: viewModel.sharesTrainingData ? .training : .trainingOff,
          onTap: viewModel.toggleTrainingData,
        ),
        const SizedBox(width: 8),
      ],
      skin.hint(
        context,
        'Display filter: ${viewModel.style?.label ?? 'Raw'}',
        skin.button(
          context,
          label: viewModel.style?.label ?? 'Raw',
          icon: .filter,
          labelled: true,
          onTap: viewModel.cycleStyle,
          onSecondaryTap: () => viewModel.cycleStyle(reverse: true),
        ),
      ),
      const SizedBox(width: 8),
      if (showPixelShape) ...[
        skin.button(
          context,
          label: viewModel.squarePixels ? '1:1' : '4:3',
          onTap: viewModel.togglePixelShape,
        ),
        const SizedBox(width: 8),
      ],
      skin.button(
        context,
        label: viewModel.speed.label,
        onTap: viewModel.cycleSpeed,
        onSecondaryTap: () => viewModel.cycleSpeed(reverse: true),
      ),
      const SizedBox(width: 8),
      // Beside the speed it governs: at 1x that button is a play triangle,
      // and the two reading as a pair is the point.
      skin.button(
        context,
        label: viewModel.isPaused ? 'Resume' : 'Pause',
        icon: viewModel.isPaused ? .play : .pause,
        onTap: viewModel.togglePause,
      ),
      const SizedBox(width: 8),
      skin.button(
        context,
        label: 'Reset',
        icon: .reset,
        onTap: viewModel.reset,
      ),
      if (transportTrailing != null) ...[
        const SizedBox(width: 8),
        transportTrailing ?? const SizedBox(),
      ],
      const SizedBox(width: 8),
      if (showFullscreen)
        skin.button(
          context,
          label: immersive ? 'Leave fullscreen' : 'Fullscreen',
          icon: immersive ? .fullscreenExit : .fullscreen,
          onTap: onFullscreen,
        ),
    ];
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(mainAxisSize: MainAxisSize.min, children: controls),
          ),
        ),
        const SizedBox(width: 8),
        skin.button(
          context,
          label: viewModel.isMuted ? 'Unmute' : 'Mute',
          icon: viewModel.isMuted ? .muted : .sound,
          onTap: viewModel.toggleMuted,
        ),
      ],
    );
  }
}

/// The picture with its controls laid over it, the way a video player does
/// it: they arrive with the pointer and leave once it settles.
class _Immersive extends StatefulWidget {
  const _Immersive({required this.picture, required this.transport});

  final Widget picture;
  final Widget transport;

  @override
  State<_Immersive> createState() => _ImmersiveState();
}

class _ImmersiveState extends State<_Immersive> {
  static const _linger = Duration(seconds: 3);

  bool _showing = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _wake();
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _wake() {
    _hide?.cancel();
    _hide = Timer(_linger, () {
      if (mounted) setState(() => _showing = false);
    });
    if (!_showing) setState(() => _showing = true);
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onHover: (_) => _wake(),
    cursor: _showing ? SystemMouseCursors.basic : SystemMouseCursors.none,
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.picture,
        Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child: IgnorePointer(
            ignoring: !_showing,
            child: AnimatedOpacity(
              opacity: _showing ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: widget.transport,
            ),
          ),
        ),
      ],
    ),
  );
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
      _ => 'Pick a game',
    };

    return Center(child: skin.text(context, message, role: .caption));
  }
}

/// A cartridge's own picture: the frame it was photographed on, or the one
/// the player is looking at when it is the game on the screen.
class _Preview extends StatelessWidget {
  const _Preview({required this.viewModel, required this.rom});

  final EmulatorViewModel viewModel;
  final RomFile rom;

  @override
  Widget build(BuildContext context) {
    final live = viewModel.playing == rom ? viewModel.session.frames : null;
    if (live == null) {
      return _Picture(viewModel: viewModel, image: viewModel.pictureOf(rom));
    }

    return RepaintBoundary(
      child: ValueListenableBuilder<ui.Image?>(
        valueListenable: live,
        builder: (context, frame, _) => _Picture(
          viewModel: viewModel,
          image: frame ?? viewModel.pictureOf(rom),
        ),
      ),
    );
  }
}

class _Picture extends StatelessWidget {
  const _Picture({required this.viewModel, required this.image});

  final EmulatorViewModel viewModel;
  final ui.Image? image;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    if (image == null) return const SizedBox.shrink();

    // The console's shape, not the frame buffer's — its pixels are not
    // square, so the picture is wider than the numbers say.
    return AspectRatio(
      aspectRatio: viewModel.aspectFor(image.width, image.height),
      child: RawImage(image: image, fit: .fill, filterQuality: .none),
    );
  }
}

/// The cartridges, in a row. Public because a host with its own chrome puts
/// the shelf in a box of its own rather than under the screen.
class EmulatorShelf extends StatelessWidget {
  const EmulatorShelf({required this.viewModel, required this.skin, super.key});

  final EmulatorViewModel viewModel;
  final EmulatorSkin skin;

  @override
  Widget build(BuildContext context) {
    final roms = viewModel.roms;

    return LayoutBuilder(
      builder: (context, outerConstraints) => skin.panel(
        context,
        title: 'Collection',
        fill: outerConstraints.hasBoundedHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final rowHeight = skin.cartridgePicture * 3 / 4 + 20;
            final grid =
                constraints.hasBoundedHeight &&
                constraints.maxHeight >= rowHeight * 2 + 8 &&
                constraints.maxWidth >= skin.cartridgeWidth * 2 + 8;

            Widget cartridge(int i) => skin.cartridge(
              context,
              title: roms[i].title,
              year: roms[i].year,
              playing: roms[i] == viewModel.playing,
              preview: _Preview(viewModel: viewModel, rom: roms[i]),
              slots: StateSlots(
                viewModel: viewModel,
                rom: roms[i],
                saving: false,
                showIcon: false,
              ),
              onTap: () => viewModel.play(roms[i]),
              onRemove: () => viewModel.remove(roms[i]),
            );

            if (roms.isEmpty) {
              return SizedBox(
                height: rowHeight,
                child: Center(
                  child: skin.text(
                    context,
                    'No cartridges yet',
                    role: .caption,
                  ),
                ),
              );
            }
            final content = grid
                ? GridView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: roms.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          ((constraints.maxWidth + 8) /
                                  (skin.cartridgeWidth + 8))
                              .floor(),
                      mainAxisExtent: rowHeight,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (_, i) => cartridge(i),
                  )
                : SizedBox(
                    height: constraints.hasBoundedHeight
                        ? math.min(rowHeight, constraints.maxHeight)
                        : rowHeight,
                    child: ListView.separated(
                      scrollDirection: .horizontal,
                      itemCount: roms.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => cartridge(i),
                    ),
                  );
            return constraints.hasBoundedHeight && !grid
                ? Align(alignment: Alignment.topLeft, child: content)
                : content;
          },
        ),
      ),
    );
  }
}
