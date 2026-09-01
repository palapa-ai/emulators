import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emulator/emulator.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'api_panel.dart';
import 'assistant_panel.dart';

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
      title: 'Emulator',
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

  static const _drop = MethodChannel('emulators_example/drop');

  bool _over = false;
  bool _showApi = false;

  @override
  void initState() {
    super.initState();
    _drop.setMethodCallHandler(_onDrop);
    _drop.invokeMethod('accept', [
      for (final system in RomSystem.values)
        for (final extension in system.extensions) extension.substring(1),
    ]);
  }

  Future<void> _onDrop(MethodCall call) async {
    switch (call.method) {
      case 'over':
        setState(() => _over = call.arguments as bool);
      case 'dropped':
        setState(() => _over = false);
        await _viewModel.addFiles((call.arguments as List).cast<String>());
    }
  }

  @override
  void dispose() {
    _drop.setMethodCallHandler(null);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const skin = EmulatorSkin();

    return ColoredBox(
      color: skin.background(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: _over ? skin.accent(context) : const Color(0x00000000),
            width: 2,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ListenableBuilder(
              listenable: _viewModel,
              // Built once, not per notification: they drive themselves, and
              // an identical child skips rebuilding, so a button press does
              // not re-run every visible hex row.
              child: Row(
                crossAxisAlignment: .stretch,
                children: [
                  Expanded(
                    child: _Log(viewModel: _viewModel, skin: skin),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: MemoryView(viewModel: _viewModel)),
                ],
              ),
              builder: (context, bottomRow) => Row(
                crossAxisAlignment: .stretch,
                children: [
                  SizedBox(
                    width: 570,
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        // The model's half of the workbench, over the shelf
                        // it is talking about.
                        Expanded(
                          child: _showApi
                              ? ApiPanel(viewModel: _viewModel, skin: skin)
                              : AssistantPanel(
                                  viewModel: _viewModel,
                                  skin: skin,
                                ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _Library(viewModel: _viewModel, skin: skin),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        Expanded(
                          flex: 7,
                          child: EmulatorScreen(
                            viewModel: _viewModel,
                            showShelf: false,
                            transportLeading: Row(
                              mainAxisSize: .min,
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
                            transportTrailing: skin.button(
                              context,
                              label: _showApi ? 'Assistant' : 'API',
                              onTap: () => setState(() => _showApi = !_showApi),
                            ),
                            // The package hides its own chrome; the window
                            // still has to be told to fill the display.
                            onFullscreen: (on) =>
                                _drop.invokeMethod('fullscreen', on),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PadTicker(viewModel: _viewModel, skin: skin),
                        const SizedBox(height: 12),
                        Expanded(flex: 2, child: bottomRow ?? const SizedBox()),
                      ],
                    ),
                  ),
                ],
              ),
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

    final counts = {
      for (final system in RomSystem.values)
        system: roms.where((r) => r.system == system).length,
    };

    return skin.panel(
      context,
      title: counts.entries
          .map((e) => '${e.key.label} (${e.value})')
          .join('   '),
      // Lazy on purpose: a card only exists while it is near the viewport,
      // which is what tells the view model to run or drop its preview.
      child: Expanded(
        child: roms.isEmpty
            ? Center(
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    const EmulatorGlyph(
                      EmulatorIcon.load,
                      size: 18,
                      color: Color(0x8ce8e8ee),
                    ),
                    const SizedBox(width: 8),
                    skin.text(
                      context,
                      'Drag and drop cartridges here',
                      role: .caption,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: roms.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PreviewScope(
                    key: ValueKey(roms[i].path),
                    viewModel: viewModel,
                    rom: roms[i],
                    child: _LibraryCard(
                      viewModel: viewModel,
                      skin: skin,
                      rom: roms[i],
                      playing: roms[i] == viewModel.playing,
                    ),
                  ),
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

/// Runs a cartridge's preview for exactly as long as its card is built, so
/// scrolling one off the shelf unloads the emulator behind it.
class _PreviewScope extends StatefulWidget {
  const _PreviewScope({
    super.key,
    required this.viewModel,
    required this.rom,
    required this.child,
  });

  final EmulatorViewModel viewModel;
  final RomFile rom;
  final Widget child;

  @override
  State<_PreviewScope> createState() => _PreviewScopeState();
}

class _PreviewScopeState extends State<_PreviewScope> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.showPreview(widget.rom);
  }

  @override
  void dispose() {
    widget.viewModel.hidePreview(widget.rom);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    final session = viewModel.sessionFor(rom);

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
          crossAxisAlignment: .stretch,
          children: [
            Row(
              crossAxisAlignment: .start,
              children: [
                SizedBox(
                  width: 120,
                  // Listening per card keeps one preview's frame from
                  // rebuilding the whole window. The box takes the frame's
                  // own shape, so the picture meets its edges with no bars.
                  child: session == null
                      ? AspectRatio(
                          aspectRatio: 4 / 3,
                          child: ColoredBox(color: skin.screen(context)),
                        )
                      : RepaintBoundary(
                          child: ValueListenableBuilder<ui.Image?>(
                            valueListenable: session.frames,
                            builder: (context, frame, _) => AspectRatio(
                              aspectRatio: frame == null
                                  ? 4 / 3
                                  : frame.width / frame.height,
                              child: frame == null
                                  ? ColoredBox(color: skin.screen(context))
                                  : RawImage(
                                      image: frame,
                                      fit: .fill,
                                      filterQuality: .none,
                                    ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      skin.text(context, rom.title, maxLines: 2),
                      const SizedBox(height: 4),
                      _CopyPath(rom: rom, skin: skin),
                      const SizedBox(height: 4),
                      skin.text(context, rom.sizeLabel, role: .caption),
                      if (rom.note case final note?) ...[
                        const SizedBox(height: 6),
                        skin.text(context, note, role: .caption, maxLines: 3),
                      ],
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
                          ).clickable,
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).clickable;
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
      mainAxisSize: .min,
      children: [
        if (showLabel)
          EmulatorGlyph(
            saving ? EmulatorIcon.save : EmulatorIcon.load,
            size: 16,
          ),
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
          ).clickable,
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
            color: _copied ? const Color(0xff7fd4a8) : const Color(0x8ce8e8ee),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: widget.skin.text(
              context,
              widget.rom.fileName,
              role: .caption,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ).clickable;
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
      title: '',
      leading: [
        skin.button(
          context,
          label: viewModel.sharesTrainingData
              ? 'sharing training data'
              : 'not sharing training data',
          icon: .training,
          labelled: true,
          onTap: viewModel.toggleTrainingData,
        ),
      ],
      trailing: [
        if (viewModel.padName case final pad?)
          Row(
            mainAxisSize: .min,
            children: [
              const EmulatorGlyph(
                EmulatorIcon.controller,
                size: 13,
                color: Color(0x8ce8e8ee),
              ),
              const SizedBox(width: 6),
              skin.text(context, pad, role: .caption),
            ],
          )
        else
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: ControllerPairing.open,
              child: Row(
                mainAxisSize: .min,
                children: [
                  const EmulatorGlyph(
                    EmulatorIcon.controller,
                    size: 13,
                    color: Color(0x8ce8e8ee),
                  ),
                  const SizedBox(width: 6),
                  skin.text(context, 'Connect controller', role: .caption),
                ],
              ),
            ),
          ),
      ],
      child: SizedBox(
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
                    role: i == 0
                        ? EmulatorTextRole.heading
                        : EmulatorTextRole.caption,
                  ),
                ),
              ),
            ),
          ],
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
    return CollapsingPanel(
      title: 'Log',
      // Listens for itself, so it can sit outside the workbench's rebuild
      // and only its own list re-runs when a line lands.
      child: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => _list(viewModel.logLines),
      ),
    );
  }

  Widget _list(List<String> lines) => ListView.builder(
    reverse: true,
    padding: EdgeInsets.zero,
    itemCount: lines.length,
    itemBuilder: (_, i) {
      final row = lines.length - 1 - i;
      return ColoredBox(
        color: row.isEven ? const Color(0x00000000) : const Color(0x0affffff),
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
  );
}
