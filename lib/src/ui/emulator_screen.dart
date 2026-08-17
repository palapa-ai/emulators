import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../emulator_button.dart';
import '../emulator_session.dart';
import '../rom_file.dart';
import '../rom_library.dart';
import 'emulator_skin.dart';

final _keyBindings = <LogicalKeyboardKey, EmulatorButton>{
  LogicalKeyboardKey.arrowUp: EmulatorButton.up,
  LogicalKeyboardKey.arrowDown: EmulatorButton.down,
  LogicalKeyboardKey.arrowLeft: EmulatorButton.left,
  LogicalKeyboardKey.arrowRight: EmulatorButton.right,
  LogicalKeyboardKey.keyZ: EmulatorButton.b,
  LogicalKeyboardKey.keyX: EmulatorButton.a,
  LogicalKeyboardKey.keyA: EmulatorButton.y,
  LogicalKeyboardKey.keyS: EmulatorButton.x,
  LogicalKeyboardKey.keyQ: EmulatorButton.l,
  LogicalKeyboardKey.keyW: EmulatorButton.r,
  LogicalKeyboardKey.enter: EmulatorButton.start,
  LogicalKeyboardKey.shiftRight: EmulatorButton.select,
};

/// The whole feature: the running game over the shelf it came from.
///
/// Everything it draws goes through [EmulatorSkin], so a host restyles it by
/// wrapping this in an [EmulatorTheme] rather than rebuilding the screen.
class EmulatorScreen extends StatefulWidget {
  const EmulatorScreen({this.corePath, this.libraryRoot, super.key});

  final String? corePath;
  final String? libraryRoot;

  @override
  State<EmulatorScreen> createState() => EmulatorScreenState();
}

class EmulatorScreenState extends State<EmulatorScreen> {
  EmulatorSession? _session;
  RomLibrary? _library;
  List<RomFile> _roms = const [];

  @override
  void initState() {
    super.initState();
    _session = EmulatorSession(corePath: widget.corePath)
      ..addListener(_onSessionChanged);
    _library = RomLibrary(rootPath: widget.libraryRoot);
    refresh();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  /// Hosts that add cartridges their own way (a drop target, a file picker)
  /// call these after the folder changes.
  Future<void> refresh() async {
    final roms = await _library?.load() ?? const <RomFile>[];
    if (mounted) setState(() => _roms = roms);
  }

  Future<void> addFiles(Iterable<String> paths) async {
    final roms = await _library?.add(paths) ?? const <RomFile>[];
    if (mounted) setState(() => _roms = roms);
  }

  Future<void> _remove(RomFile rom) async {
    if (_session?.rom == rom) _session?.stop();
    final roms = await _library?.remove(rom) ?? const <RomFile>[];
    if (mounted) setState(() => _roms = roms);
  }

  @override
  void dispose() {
    _session?.removeListener(_onSessionChanged);
    _session?.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    final button = _keyBindings[event.logicalKey];
    if (button == null) return KeyEventResult.ignored;
    if (event is KeyRepeatEvent) return KeyEventResult.handled;

    _session?.press(button, pressed: event is KeyDownEvent);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final skin = EmulatorTheme.of(context);
    final session = _session;

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ColoredBox(
        color: skin.background(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: session == null
                  ? const SizedBox.shrink()
                  : _Stage(session: session, skin: skin),
            ),
            const SizedBox(height: 16),
            _Shelf(
              roms: _roms,
              playing: session?.rom,
              skin: skin,
              onPlay: (rom) => session?.play(rom),
              onRemove: _remove,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.session, required this.skin});

  final EmulatorSession session;
  final EmulatorSkin skin;

  @override
  Widget build(BuildContext context) {
    final rom = session.rom;
    if (rom == null) return _Idle(session: session, skin: skin);

    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: skin.screen(context),
            child: Center(
              child: AspectRatio(
                aspectRatio: session.aspectRatio,
                child: session.frame == null
                    ? const SizedBox.expand()
                    : RawImage(image: session.frame, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            skin.text(context, rom.title, role: EmulatorTextRole.heading),
            const Spacer(),
            skin.button(context, label: 'Reset', onTap: session.reset),
            const SizedBox(width: 8),
            skin.button(context, label: 'Eject', onTap: session.stop),
          ],
        ),
      ],
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle({required this.session, required this.skin});

  final EmulatorSession session;
  final EmulatorSkin skin;

  @override
  Widget build(BuildContext context) {
    final message = switch (session.status) {
      SessionStatus.unavailable =>
        'No emulator core is bundled for this platform',
      SessionStatus.failed => session.error ?? 'That cartridge would not load',
      _ => 'Pick a cartridge below',
    };

    return Center(
      child: skin.text(context, message, role: EmulatorTextRole.caption),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.roms,
    required this.playing,
    required this.skin,
    required this.onPlay,
    required this.onRemove,
  });

  final List<RomFile> roms;
  final RomFile? playing;
  final EmulatorSkin skin;
  final void Function(RomFile) onPlay;
  final void Function(RomFile) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            skin.text(context, 'Collection', role: EmulatorTextRole.heading),
            const SizedBox(width: 8),
            skin.text(
              context,
              '${roms.length}',
              role: EmulatorTextRole.caption,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 104,
          child: roms.isEmpty
              ? Center(
                  child: skin.text(
                    context,
                    'No cartridges yet',
                    role: EmulatorTextRole.caption,
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: roms.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => skin.cartridge(
                    context,
                    title: roms[i].title,
                    subtitle: roms[i].sizeLabel,
                    playing: roms[i] == playing,
                    onTap: () => onPlay(roms[i]),
                    onRemove: () => onRemove(roms[i]),
                  ),
                ),
        ),
      ],
    );
  }
}
