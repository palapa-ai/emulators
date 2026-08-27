import 'package:agentic_emulator/emulators.dart';
import 'package:flutter/widgets.dart';

/// The agent surface, exercised by hand: every call the assistant may make,
/// each with a live Try against the running game.
class ApiPanel extends StatefulWidget {
  const ApiPanel({required this.viewModel, required this.skin, super.key});

  final EmulatorViewModel viewModel;
  final EmulatorSkin skin;

  @override
  State<ApiPanel> createState() => _ApiPanelState();
}

class _ApiPanelState extends State<ApiPanel> {
  final _results = <String, String>{};

  // Harmless by construction: the poke writes back the byte it just read.
  AgentCall _demo(String name) => switch (name) {
    'peek' => const AgentCall(name: 'peek', args: {'offset': 0, 'length': 16}),
    'poke' => AgentCall(
      name: 'poke',
      args: {
        'offset': 0,
        'bytes': [widget.viewModel.agent.peek(length: 1)?.first ?? 0],
      },
    ),
    'tap' => const AgentCall(name: 'tap', args: {'button': 'start'}),
    _ => AgentCall(name: name),
  };

  Future<void> _try(String name) async {
    final result = await widget.viewModel.agent.run(_demo(name));
    if (mounted) setState(() => _results[name] = '$result');
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;

    return CollapsingPanel(
      title: 'API',
      trailing: [
        skin.text(context, 'palapa.calls', role: EmulatorTextRole.caption),
      ],
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          for (final entry in EmulatorAgent.api.entries) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 11,
                          color: skin.accent(context),
                        ),
                      ),
                      skin.text(
                        context,
                        _results[entry.key] ?? entry.value,
                        role: EmulatorTextRole.caption,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                skin.button(
                  context,
                  label: 'Try',
                  onTap: () => _try(entry.key),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
