import 'dart:async';
import 'dart:io';

import 'package:emulators/emulators.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

void main() => runApp(const EmulatorsExample());

String get _defaultCore =>
    '${Platform.environment['HOME']}/Library/Application Support'
    '/ai.palapa.app/cores/snes9x2010_libretro.dylib';

String get _defaultLibrary => '${Platform.environment['HOME']}/Desktop/palapa';

const _core = String.fromEnvironment('CORE');
const _library = String.fromEnvironment('LIBRARY');

class EmulatorsExample extends StatelessWidget {
  const EmulatorsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'Emulator Palapa',
      color: const Color(0xff101014),
      builder: (context, _) => const _Workbench(),
    );
  }
}

class _Workbench extends StatefulWidget {
  const _Workbench();

  @override
  State<_Workbench> createState() => _WorkbenchState();
}

class _WorkbenchState extends State<_Workbench> {
  late final EmulatorViewModel _viewModel = EmulatorViewModel(
    corePath: _core.isEmpty ? _defaultCore : _core,
    libraryRoot: _library.isEmpty ? _defaultLibrary : _library,
    autoPlay: true,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const skin = EmulatorSkin();

    return ColoredBox(
      color: skin.background(context),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ListenableBuilder(
            listenable: _viewModel,
            builder: (context, _) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 380,
                  child: _Library(viewModel: _viewModel, skin: skin),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: EmulatorScreen(
                          viewModel: _viewModel,
                          showShelf: false,
                          transportLeading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Slots(viewModel: _viewModel, skin: skin),
                              const SizedBox(width: 16),
                              _Slots(
                                viewModel: _viewModel,
                                skin: skin,
                                saving: false,
                              ),
                            ],
                          ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PadTicker(viewModel: _viewModel, skin: skin),
                      const SizedBox(height: 12),
                      _Log(viewModel: _viewModel, skin: skin),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Library extends StatelessWidget {
  const _Library({required this.viewModel, required this.skin});

  final EmulatorViewModel viewModel;
  final EmulatorSkin skin;

  @override
  Widget build(BuildContext context) {
    final roms = viewModel.roms;
    final onScreen = roms.take(EmulatorViewModel.maxPreviews).toList();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => viewModel.setVisible(onScreen),
    );

    final counts = {
      for (final system in RomSystem.values)
        system: roms.where((r) => r.system == system).length,
    };

    return skin.panel(
      context,
      title: counts.entries
          .map((e) => '${e.key.label} (${e.value})')
          .join('   '),
      child: Expanded(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final rom in roms.take(EmulatorViewModel.maxPreviews + 3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LibraryCard(
                    viewModel: viewModel,
                    skin: skin,
                    rom: rom,
                    playing: rom == viewModel.playing,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

/// Swapping cartridges tears down and reopens a core; a double tap should not
/// start that twice.
void _debounced(VoidCallback action) {
  final now = DateTime.now();
  if (now.difference(_lastTap) < const Duration(milliseconds: 400)) return;
  _lastTap = now;
  action();
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.viewModel,
    required this.skin,
    required this.rom,
    required this.playing,
  });

  final EmulatorViewModel viewModel;
  final EmulatorSkin skin;
  final RomFile rom;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final frame = viewModel.sessionFor(rom)?.frame;

    return GestureDetector(
      onTap: () => _debounced(() => viewModel.play(rom)),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(
            color: playing ? skin.accent(context) : skin.line(context),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: ColoredBox(
                      color: skin.screen(context),
                      child: frame == null
                          ? const SizedBox.expand()
                          : RawImage(image: frame, fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      skin.text(context, rom.title, maxLines: 2),
                      const SizedBox(height: 4),
                      skin.text(
                        context,
                        rom.sizeLabel,
                        role: EmulatorTextRole.caption,
                      ),
                      if (rom.note case final note?) ...[
                        const SizedBox(height: 6),
                        skin.text(
                          context,
                          note,
                          role: EmulatorTextRole.caption,
                          maxLines: 3,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _Slots(
                    viewModel: viewModel,
                    skin: skin,
                    rom: rom,
                    saving: false,
                    showLabel: false,
                  ),
                ),
                GestureDetector(
                  onTap: () => viewModel.remove(rom),
                  child: const EmulatorGlyph(
                    EmulatorIcon.delete,
                    size: 16,
                    color: Color(0xffe05a5a),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _CopyPath(rom: rom, skin: skin),
          ],
        ),
      ),
    );
  }
}

class _Slots extends StatelessWidget {
  const _Slots({
    required this.viewModel,
    required this.skin,
    this.rom,
    this.saving = true,
    this.showLabel = true,
  });

  final EmulatorViewModel viewModel;
  final EmulatorSkin skin;
  final RomFile? rom;
  final bool saving;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final target = rom ?? viewModel.playing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) skin.text(context, saving ? 'Save' : 'Load'),
        for (var slot = 1; slot <= EmulatorViewModel.slotCount; slot++) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => saving
                ? viewModel.saveState(slot)
                : viewModel.loadState(slot, from: rom),
            // A filled slot reads as available; an empty one stays quiet.
            child: Text(
              const ['①', '②', '③'][slot - 1],
              style: TextStyle(
                fontSize: 20,
                color: target != null && viewModel.hasState(target, slot)
                    ? skin.accent(context)
                    : const Color(0x8ce8e8ee),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CopyPath extends StatefulWidget {
  const _CopyPath({required this.rom, required this.skin});

  final RomFile rom;
  final EmulatorSkin skin;

  @override
  State<_CopyPath> createState() => _CopyPathState();
}

class _CopyPathState extends State<_CopyPath> {
  Timer? _confirm;
  bool _copied = false;

  @override
  void dispose() {
    _confirm?.cancel();
    super.dispose();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.rom.path));
    setState(() => _copied = true);
    _confirm?.cancel();
    _confirm = Timer(
      const Duration(seconds: 2),
      () => mounted ? setState(() => _copied = false) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _copy,
      child: Row(
        children: [
          EmulatorGlyph(
            _copied ? EmulatorIcon.check : EmulatorIcon.copy,
            size: 13,
            color: _copied
                ? const Color(0xff7fd4a8)
                : const Color(0x8ce8e8ee),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: widget.skin.text(
              context,
              widget.rom.fileName,
              role: EmulatorTextRole.caption,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PadTicker extends StatelessWidget {
  const _PadTicker({required this.viewModel, required this.skin});

  final EmulatorViewModel viewModel;
  final EmulatorSkin skin;

  @override
  Widget build(BuildContext context) {
    final presses = viewModel.padLog;

    return skin.panel(
      context,
      title: 'Button Log',
      trailing: [
        skin.text(
          context,
          'mask ${viewModel.heldMask}  pad ${viewModel.padMask}  '
'${viewModel.padName ?? 'no pad'}',
          role: EmulatorTextRole.caption,
        ),
      ],
      child: SizedBox(
        height: 24,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          reverse: true,
          itemCount: presses.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Center(
            child: skin.text(
              context,
              presses[presses.length - 1 - i].label,
              role: i == 0 ? EmulatorTextRole.heading : EmulatorTextRole.caption,
            ),
          ),
        ),
      ),
    );
  }
}

class _Log extends StatelessWidget {
  const _Log({required this.viewModel, required this.skin});

  final EmulatorViewModel viewModel;
  final EmulatorSkin skin;

  @override
  Widget build(BuildContext context) {
    final lines = viewModel.logLines;

    return skin.panel(
      context,
      title: 'Log',
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          reverse: true,
          padding: EdgeInsets.zero,
          itemCount: lines.length,
          itemBuilder: (_, i) {
            final row = lines.length - 1 - i;
            return ColoredBox(
              color: row.isEven
                  ? const Color(0x00000000)
                  : const Color(0x0affffff),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Text(
                  lines[row],
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 10,
                    height: 1.4,
                    color: Color(0x99e8e8ee),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
