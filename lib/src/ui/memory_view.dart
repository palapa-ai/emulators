import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'collapsing_panel.dart';
import 'emulator_skin.dart';
import 'emulator_view_model.dart';

/// The debugger's window on work RAM: a hex dump that follows the running
/// game, with the bytes that moved since the last look picked out.
class MemoryView extends StatefulWidget {
  const MemoryView({required this.viewModel, super.key});

  final EmulatorViewModel viewModel;

  @override
  State<MemoryView> createState() => _MemoryViewState();
}

class _MemoryViewState extends State<MemoryView> {
  static const _bytesPerRow = 16;

  Timer? _poll;
  Uint8List? _current;
  Uint8List? _previous;

  @override
  void initState() {
    super.initState();
    // RAM is a live view onto core memory — snapshot it, both so a paint sees
    // a stable buffer and so the previous frame is there to diff against.
    // A paused core writes nothing, so its RAM is only copied once.
    _poll = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final session = widget.viewModel.session;
      if (session.isPaused && _current != null) return;
      final ram = session.systemRam;
      if (ram == null) {
        // The game is gone — showing its last RAM would be a lie.
        if (_current != null) {
          setState(() {
            _previous = null;
            _current = null;
          });
        }
        return;
      }
      setState(() {
        _previous = _current;
        _current = Uint8List.fromList(ram);
      });
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = EmulatorTheme.of(context);
    final ram = _current;

    return CollapsingPanel(
      title: 'Memory',
      trailing: [
        if (ram != null)
          skin.text(
            context,
            '${ram.length ~/ 1024} KB',
            role: EmulatorTextRole.caption,
          ),
      ],
      child: ram == null
          ? Center(
              child: skin.text(
                context,
                'No RAM exposed',
                role: EmulatorTextRole.caption,
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                // One line when the panel can hold offset, hex and text side
                // by side; otherwise the text drops to its own line below.
                final style = _monoStyle(skin, context);
                final painter = TextPainter(
                  text: TextSpan(text: '0' * 10, style: style),
                  textDirection: TextDirection.ltr,
                )..layout();
                final charWidth = painter.width / 10;
                final wide = constraints.maxWidth >= charWidth * 74;

                return ListView.builder(
                  itemExtent: wide ? 18 : 34,
                  itemCount: (ram.length / _bytesPerRow).ceil(),
                  itemBuilder: (context, row) => _Row(
                    skin: skin,
                    ram: ram,
                    previous: _previous,
                    offset: row * _bytesPerRow,
                    wide: wide,
                  ),
                );
              },
            ),
    );
  }
}

TextStyle _monoStyle(EmulatorSkin skin, BuildContext context) =>
    // Hex columns only line up in a fixed-width face.
    skin
        .textStyle(context, EmulatorTextRole.caption)
        .copyWith(
          fontFamily: 'Menlo',
          fontFamilyFallback: const ['Monaco', 'Courier New', 'monospace'],
        );

class _Row extends StatelessWidget {
  const _Row({
    required this.skin,
    required this.ram,
    required this.previous,
    required this.offset,
    required this.wide,
  });

  final EmulatorSkin skin;
  final Uint8List ram;
  final Uint8List? previous;
  final int offset;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final base = _monoStyle(skin, context);
    final quiet = base.color ?? const Color(0x8ce8e8ee);
    final hot = skin.accent(context);
    final end = (offset + _MemoryViewState._bytesPerRow).clamp(0, ram.length);

    final hex = <TextSpan>[];
    final ascii = StringBuffer();
    for (var i = offset; i < end; i++) {
      final byte = ram[i];
      final moved = previous != null && i < previous!.length
          ? previous![i] != byte
          : false;
      hex.add(
        TextSpan(
          text: '${byte.toRadixString(16).padLeft(2, '0')} ',
          style: moved ? base.copyWith(color: hot) : null,
        ),
      );
      ascii.write(
        byte >= 0x20 && byte < 0x7f ? String.fromCharCode(byte) : '.',
      );
    }

    final label = TextSpan(
      text: '${offset.toRadixString(16).padLeft(6, '0')}  ',
    );

    if (wide) {
      return Text.rich(
        TextSpan(
          style: base.copyWith(color: quiet),
          children: [
            label,
            ...hex,
            TextSpan(text: ' $ascii'),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.clip,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: base.copyWith(color: quiet),
            children: [label, ...hex],
          ),
          maxLines: 1,
          overflow: TextOverflow.clip,
        ),
        Text(
          '        ↳ $ascii',
          style: base.copyWith(color: quiet),
          maxLines: 1,
          overflow: TextOverflow.clip,
        ),
      ],
    );
  }
}
