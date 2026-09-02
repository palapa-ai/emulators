import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controller_pairing.dart';
import '../emulator_button.dart';
import '../emulator_session.dart';
import 'emulator_glyph.dart';
import 'emulator_skin.dart';
import 'emulator_view_model.dart';
import 'style_shader_view.dart';

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

    final button = _keyBindings[event.logicalKey];
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
                  _Shelf(viewModel: viewModel, skin: skin),
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
    this.onPairController,
    this.transportLeading,
    this.transportTrailing,
  });

  final EmulatorViewModel viewModel;
  final EmulatorSkin skin;
  final bool immersive;
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
                  aspectRatio: frame.width / frame.height,
                  child: StyleShaderView(frame: frame, style: style),
                ),
                (final frame?, null) => AspectRatio(
                  aspectRatio: frame.width / frame.height,
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
    );
  }

  Widget _transport(BuildContext context) {
    return Row(
      children: [
        if (transportLeading != null) transportLeading ?? const SizedBox(),
        const Spacer(),
        // With no pad attached the package can still get the user to the
        // system's pairing pane, so the affordance does not wait on a host.
        if (onPairController != null ||
            (viewModel.gamepadName == null && ControllerPairing.canOpen)) ...[
          skin.button(
            context,
            label: viewModel.gamepadName ?? 'Connect controller',
            icon: .controller,
            onTap: onPairController ?? ControllerPairing.open,
          ),
          const SizedBox(width: 8),
        ],
        skin.button(
          context,
          label: viewModel.style?.label ?? 'Raw',
          icon: viewModel.style.icon,
          onTap: viewModel.cycleStyle,
          onSecondaryTap: () => viewModel.cycleStyle(reverse: true),
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
          icon: viewModel.speed.icon,
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
        skin.button(
          context,
          label: immersive ? 'Leave fullscreen' : 'Fullscreen',
          icon: immersive ? .fullscreenExit : .fullscreen,
          onTap: onFullscreen,
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
      _ => 'Pick a cartridge below',
    };

    return Center(child: skin.text(context, message, role: .caption));
  }
}

/// A cartridge's own picture, running or parked. Watched per card so one
/// frame repaints one thumbnail instead of the whole shelf.
class _Preview extends StatelessWidget {
  const _Preview({required this.session});

  final EmulatorSession? session;

  @override
  Widget build(BuildContext context) {
    final session = this.session;
    if (session == null) return const SizedBox.shrink();

    return RepaintBoundary(
      child: ValueListenableBuilder<ui.Image?>(
        valueListenable: session.frames,
        builder: (context, frame, _) => frame == null
            ? const SizedBox.shrink()
            : AspectRatio(
                aspectRatio: frame.width / frame.height,
                child: RawImage(image: frame, fit: .fill, filterQuality: .none),
              ),
      ),
    );
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
                child: skin.text(context, 'No cartridges yet', role: .caption),
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
                  preview: _Preview(session: viewModel.sessionFor(roms[i])),
                  onTap: () => viewModel.play(roms[i]),
                  onRemove: () => viewModel.remove(roms[i]),
                ),
              ),
      ),
    );
  }
}
