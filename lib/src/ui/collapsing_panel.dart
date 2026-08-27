import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'emulator_skin.dart';

/// A panel whose chrome steps aside while the reader heads into the list,
/// and returns the moment they turn back.
class CollapsingPanel extends StatefulWidget {
  const CollapsingPanel({
    required this.title,
    required this.child,
    this.trailing = const [],
    super.key,
  });

  final String title;
  final List<Widget> trailing;
  final Widget child;

  @override
  State<CollapsingPanel> createState() => _CollapsingPanelState();
}

class _CollapsingPanelState extends State<CollapsingPanel> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final skin = EmulatorTheme.of(context);

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        final hidden = switch (notification.direction) {
          ScrollDirection.reverse => true,
          ScrollDirection.forward => false,
          ScrollDirection.idle => _hidden,
        };
        if (hidden != _hidden) setState(() => _hidden = hidden);
        return false;
      },
      child: skin.panel(
        context,
        title: _hidden ? '' : widget.title,
        trailing: _hidden ? const [] : widget.trailing,
        fill: true,
        child: widget.child,
      ),
    );
  }
}
