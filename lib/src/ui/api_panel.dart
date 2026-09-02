import 'package:flutter/widgets.dart';

import '../emulator_agent.dart';
import '../emulator_assistant.dart';
import 'collapsing_panel.dart';
import 'emulator_skin.dart';
import 'emulator_view_model.dart';

/// The agent surface, exercised by hand: every call the assistant may make,
/// each with a live Try against the running game.
class ApiPanel extends StatefulWidget {
  const ApiPanel({required this.viewModel, super.key});

  final EmulatorViewModel viewModel;

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
    final skin = EmulatorTheme.of(context);
    final names = EmulatorAgent.api.keys.toList();

    return CollapsingPanel(
      title: 'API',
      trailing: [skin.text(context, 'palapa.calls', role: .caption)],
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: names.length,
        separatorBuilder: (_, _) => Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: skin.line(context),
        ),
        itemBuilder: (context, i) => _Call(
          skin: skin,
          name: names[i],
          description: EmulatorAgent.api[names[i]] ?? '',
          // What came back stands under the call rather than in place of
          // what the call is for.
          result: _results[names[i]],
          onTry: () => _try(names[i]),
        ),
      ),
    );
  }
}

class _Call extends StatelessWidget {
  const _Call({
    required this.skin,
    required this.name,
    required this.description,
    required this.result,
    required this.onTry,
  });

  final EmulatorSkin skin;
  final String name;
  final String description;
  final String? result;
  final VoidCallback onTry;

  @override
  Widget build(BuildContext context) {
    final mono = skin
        .textStyle(context, EmulatorTextRole.caption)
        .copyWith(fontFamily: 'Menlo', height: 1.45);

    return Row(
      crossAxisAlignment: .start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text(name, style: mono.copyWith(color: skin.accent(context))),
              const SizedBox(height: 2),
              skin.text(context, description, role: .caption, maxLines: 2),
              if (result case final result?) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: skin.line(context).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    result.isEmpty ? 'done' : result,
                    style: mono.copyWith(
                      color: skin.textStyle(context, .body).color,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        skin.button(context, label: 'Try', onTap: onTry),
      ],
    );
  }
}
