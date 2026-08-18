import 'package:flutter/widgets.dart';

enum EmulatorTextRole { heading, body, caption }

/// Named rather than drawn here, so a host can map them onto its own icon set
/// without the package depending on one.
enum EmulatorIcon {
  reset,
  eject,
  controller,
  pause,
  play,
  delete,
  display,
  sound,
  muted,
  save,
  load,
  speed,
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
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: line(context)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: text(context, label, role: EmulatorTextRole.caption),
    ),
  );


  /// A titled region. The default is a plain bordered box; hosts with a
  /// design system draw their own.
  Widget panel(
    BuildContext context, {
    required String title,
    required Widget child,
    List<Widget> trailing = const [],
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: line(context)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            text(context, title, role: EmulatorTextRole.heading),
            const Spacer(),
            ...trailing,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );

  Widget cartridge(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool playing,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) => GestureDetector(
    onTap: onTap,
    onLongPress: onRemove,
    child: Container(
      width: 168,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: playing ? accent(context) : line(context)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          text(context, title, maxLines: 2),
          text(context, subtitle, role: EmulatorTextRole.caption),
        ],
      ),
    ),
  );
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
