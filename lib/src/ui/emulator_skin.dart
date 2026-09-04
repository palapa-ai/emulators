import 'package:flutter/widgets.dart';

import 'emulator_glyph.dart';

enum EmulatorTextRole { heading, body, caption }

/// One hand cursor for everything tappable, wherever it is drawn.
extension EmulatorTappable on Widget {
  Widget get clickable =>
      MouseRegion(cursor: SystemMouseCursors.click, child: this);
}

/// Named rather than drawn here, so a host can map them onto its own icon set
/// without the package depending on one.
enum EmulatorIcon {
  reset,
  eject,
  controller,
  pause,
  play,
  delete,
  sound,
  muted,
  save,
  load,
  copy,
  check,
  training,
  trainingOff,
  fullscreen,
  fullscreenExit,
  styleRaw,
  styleVhs,
  styleTrinitron,
  styleArcade,
  styleHomeTv,
  styleDotMatrix,
  styleNes,
  styleGameBoy,
  styleComposite,
  speedQuarter,
  speedHalf,
  speedNormal,
  speedDouble,
  speedQuad,
}

/// How the package draws its own chrome.
///
/// The defaults are deliberately plain — `package:flutter/widgets.dart` only,
/// no design system — so the package runs on its own. A host subclasses this
/// and hands it to [EmulatorTheme] to draw the same parts in its own style.
class EmulatorSkin {
  const EmulatorSkin();

  Color background(BuildContext context) => const Color(0xff101014);
  Color screen(BuildContext context) => const Color(0xff000000);
  Color accent(BuildContext context) => const Color(0xff7fd4a8);
  Color line(BuildContext context) => const Color(0x33ffffff);

  /// How wide a line of chat is allowed to get, in characters. Past about
  /// seventy the eye loses its place coming back to the left margin, which is
  /// why every chat interface lands near this number.
  int get measure => 70;

  /// [measure] in pixels, for the text the skin actually draws.
  double measureWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: '0' * measure,
        style: textStyle(context, EmulatorTextRole.body),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  TextStyle textStyle(BuildContext context, EmulatorTextRole role) =>
      switch (role) {
        EmulatorTextRole.heading => const TextStyle(
          color: Color(0xffe8e8ee),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        EmulatorTextRole.body => const TextStyle(
          color: Color(0xffe8e8ee),
          fontSize: 13,
        ),
        EmulatorTextRole.caption => const TextStyle(
          color: Color(0x8ce8e8ee),
          fontSize: 11,
        ),
      };

  Widget text(
    BuildContext context,
    String value, {
    EmulatorTextRole role = EmulatorTextRole.body,
    int? maxLines,
  }) => Text(
    value,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    style: textStyle(context, role),
  );

  Widget button(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    EmulatorIcon? icon,
    VoidCallback? onSecondaryTap,
    bool labelled = false,
  }) => _Hoverable(
    onTap: onTap,
    onSecondaryTap: onSecondaryTap,
    builder: (hovered) => Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon == null ? 12 : 8,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: hovered ? const Color(0x14ffffff) : null,
        border: Border.all(
          color: hovered ? const Color(0x66ffffff) : line(context),
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: switch ((icon, labelled)) {
        (null, _) => Text(
          label,
          style: textStyle(
            context,
            EmulatorTextRole.caption,
          ).copyWith(color: _tone(context, hovered)),
        ),
        (final icon?, false) => EmulatorGlyph(
          icon,
          color: _tone(context, hovered),
        ),
        (final icon?, true) => Row(
          mainAxisSize: .min,
          children: [
            EmulatorGlyph(icon, size: 13, color: _tone(context, hovered)),
            const SizedBox(width: 6),
            Text(
              label,
              style: textStyle(
                context,
                EmulatorTextRole.caption,
              ).copyWith(color: _tone(context, hovered)),
            ),
          ],
        ),
      },
    ),
  );

  Color? _tone(BuildContext context, bool hovered) => hovered
      ? const Color(0xffe8e8ee)
      : textStyle(context, EmulatorTextRole.caption).color;

  /// A titled region. The default is a plain bordered box; hosts with a
  /// design system draw their own.
  Widget panel(
    BuildContext context, {
    required String title,
    required Widget child,
    List<Widget> leading = const [],
    List<Widget> trailing = const [],
    bool fill = false,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: line(context)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: .stretch,
      children: [
        if (title.isNotEmpty || leading.isNotEmpty || trailing.isNotEmpty) ...[
          Row(
            children: [
              if (title.isNotEmpty) text(context, title, role: .heading),
              ...leading,
              const Spacer(),
              ...trailing,
            ],
          ),
          const SizedBox(height: 8),
        ],
        // Only a panel the caller gave a bounded height may take the slack;
        // a flex child in a wrap-content column would assert.
        if (fill) Expanded(child: child) else child,
      ],
    ),
  );

  /// How wide a cartridge stands on the shelf — its picture beside its name,
  /// with room for the name to be a name rather than an ellipsis.
  double get cartridgeWidth => 300;

  /// The picture's width; the console's shape decides its height.
  double get cartridgePicture => 128;

  Widget cartridge(
    BuildContext context, {
    required String title,
    required int? year,
    required bool playing,
    required Widget preview,
    required Widget slots,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: cartridgeWidth,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: playing ? accent(context) : line(context)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          SizedBox(
            width: cartridgePicture,
            child: ColoredBox(color: screen(context), child: preview),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                text(context, title, maxLines: 2),
                if (year != null) ...[
                  const SizedBox(height: 2),
                  text(context, '$year', role: .caption),
                ],
                const Spacer(),
                slots,
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const EmulatorGlyph(
              EmulatorIcon.delete,
              size: 13,
              color: Color(0xffe05a5a),
            ),
          ).clickable,
        ],
      ),
    ),
  ).clickable;
}

class EmulatorTheme extends InheritedWidget {
  const EmulatorTheme({required this.skin, required super.child, super.key});

  final EmulatorSkin skin;

  static EmulatorSkin of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EmulatorTheme>()?.skin ??
      const EmulatorSkin();

  @override
  bool updateShouldNotify(EmulatorTheme oldWidget) => skin != oldWidget.skin;
}

class _Hoverable extends StatefulWidget {
  const _Hoverable({
    required this.onTap,
    required this.builder,
    this.onSecondaryTap,
  });

  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;
  final Widget Function(bool hovered) builder;

  @override
  State<_Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<_Hoverable> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      onSecondaryTap: widget.onSecondaryTap,
      child: widget.builder(_hovered),
    ).clickable,
  );
}
