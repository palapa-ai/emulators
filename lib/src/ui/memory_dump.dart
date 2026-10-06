import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'emulator_skin.dart';

class MemoryDump extends StatelessWidget {
  const MemoryDump({super.key, required this.current, this.previous});
  final Uint8List current;
  final Uint8List? previous;
  static const bytesPerRow = 16;

  @override
  Widget build(BuildContext context) {
    final skin = EmulatorTheme.of(context);
    final style = skin
        .textStyle(context, .caption)
        .copyWith(
          fontFamily: 'Menlo',
          fontFamilyFallback: const ['Monaco', 'Courier New', 'monospace'],
        );
    final painter = TextPainter(
      text: TextSpan(text: '0' * 74, style: style),
      textDirection: .ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final contentWidth = painter.width.ceilToDouble();
    final rowHeight = painter.height.ceilToDouble();
    painter.dispose();

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: .horizontal,
        child: SizedBox(
          width: math.max(constraints.maxWidth, contentWidth),
          height: constraints.maxHeight,
          child: ListView.builder(
            primary: false,
            itemExtent: rowHeight,
            itemCount: (current.length / bytesPerRow).ceil(),
            itemBuilder: (context, row) => _MemoryRow(
              current: current,
              previous: previous,
              offset: row * bytesPerRow,
              style: style,
              highlight: skin.accent(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoryRow extends StatelessWidget {
  const _MemoryRow({
    required this.current,
    required this.previous,
    required this.offset,
    required this.style,
    required this.highlight,
  });
  final Uint8List current;
  final Uint8List? previous;
  final int offset;
  final TextStyle style;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    final bytes = Uint8List.sublistView(
      current,
      offset,
      math.min(offset + MemoryDump.bytesPerRow, current.length),
    );
    final ascii = bytes
        .map(
          (byte) =>
              byte >= 0x20 && byte < 0x7f ? String.fromCharCode(byte) : '.',
        )
        .join();
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: '${offset.toRadixString(16).padLeft(6, '0')}  '),
          ...bytes.indexed.map((entry) {
            final (index, byte) = entry;
            final changed = switch (previous) {
              final before? when offset + index < before.length =>
                before[offset + index] != byte,
              _ => false,
            };
            return TextSpan(
              text: '${byte.toRadixString(16).padLeft(2, '0')} ',
              style: changed ? style.copyWith(color: highlight) : null,
            );
          }),
          TextSpan(
            text: '${'   ' * (MemoryDump.bytesPerRow - bytes.length)} $ascii',
          ),
        ],
      ),
      textDirection: .ltr,
      maxLines: 1,
      softWrap: false,
      overflow: .clip,
    );
  }
}
