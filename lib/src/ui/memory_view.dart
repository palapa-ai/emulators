import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'collapsing_panel.dart';
import 'emulator_skin.dart';
import 'emulator_view_model.dart';
import 'memory_dump.dart';

/// The debugger's window on work RAM: a hex dump that follows the running
/// game, with the bytes that moved since the last look picked out.
class MemoryView extends StatefulWidget {
  const MemoryView({required this.viewModel, super.key});

  final EmulatorViewModel viewModel;

  @override
  State<MemoryView> createState() => _MemoryViewState();
}

class _MemoryViewState extends State<MemoryView> {
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
          skin.text(context, '${ram.length ~/ 1024} KB', role: .caption),
      ],
      child: ram == null
          ? Center(child: skin.text(context, 'No RAM exposed', role: .caption))
          : MemoryDump(current: ram, previous: _previous),
    );
  }
}
