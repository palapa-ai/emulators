import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../emulator_assistant.dart';
import 'collapsing_panel.dart';
import 'emulator_skin.dart';
import 'emulator_view_model.dart';

/// One turn of the conversation.
class _Turn {
  const _Turn({required this.mine, required this.text});

  final bool mine;
  final String text;
}

/// A chat with something that can see the game and reach into it.
///
/// The name is the point: a second controller was always how someone who
/// knew the game better got you past the bit you were stuck on.
class AssistantPanel extends StatefulWidget {
  const AssistantPanel({required this.viewModel, super.key});

  final EmulatorViewModel viewModel;

  @override
  State<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<AssistantPanel> {
  // The key stays in this controller for the life of the window — never
  // written to disk, never echoed into the log.
  final _url = TextEditingController();
  final _key = TextEditingController();
  final _question = TextEditingController();
  final _scroll = ScrollController();

  final _turns = <_Turn>[];
  bool _busy = false;

  /// A host that brought its own model needs no endpoint typed at it.
  bool get _needsEndpoint => widget.viewModel.assistant == null;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    _question.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String question) async {
    if (question.isEmpty || _busy) return;
    if (_needsEndpoint && _url.text.isEmpty) return;

    if (_needsEndpoint) {
      widget.viewModel.assistant = HttpAssistant(
        url: _url.text,
        apiKey: _key.text,
      );
    }

    _question.clear();
    setState(() {
      _turns.add(_Turn(mine: true, text: question));
      _busy = true;
    });

    try {
      final answer = await widget.viewModel.askAssistant(question);
      if (mounted) {
        setState(() => _turns.add(_Turn(mine: false, text: answer ?? '')));
      }
    } on Object catch (e) {
      if (mounted) setState(() => _turns.add(_Turn(mine: false, text: '$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = EmulatorTheme.of(context);

    return CollapsingPanel(
      title: '',
      trailing: [if (_busy) skin.text(context, 'thinking…', role: .caption)],
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          if (_needsEndpoint) ...[
            Row(
              children: [
                Expanded(
                  child: _Field(hint: 'https://api…/v1', controller: _url),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _Field(
                    hint: 'API key',
                    controller: _key,
                    obscure: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              reverse: true,
              padding: EdgeInsets.zero,
              itemCount: _turns.length,
              itemBuilder: (context, i) {
                final turn = _turns[_turns.length - 1 - i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: skin.measureWidth(context),
                    ),
                    child: skin.text(
                      context,
                      turn.mine ? '> ${turn.text}' : turn.text,
                      role: turn.mine ? .body : .caption,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          _Field(
            hint: 'Ask about the game…',
            controller: _question,
            onSubmitted: _send,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatefulWidget {
  const _Field({
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.onSubmitted,
  });

  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  // The keyboard shortcuts come with WidgetsApp; the right-click paste is
  // for the key that arrives on the clipboard rather than by typing.
  Future<void> _paste() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text;
    if (text == null || text.isEmpty) return;

    final value = widget.controller.value;
    final selection = value.selection;
    final at = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    widget.controller.value = TextEditingValue(
      text: value.text.replaceRange(at, end, text),
      selection: TextSelection.collapsed(offset: at + text.length),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // The host's own body text, in a fixed-width face: a key and a URL are
    // read character by character.
    final skin = EmulatorTheme.of(context);
    final ink = skin.textStyle(context, EmulatorTextRole.body).color;
    final style = skin
        .textStyle(context, EmulatorTextRole.caption)
        .copyWith(color: ink, fontFamily: 'Menlo');

    return GestureDetector(
      onTap: _focus.requestFocus,
      onSecondaryTap: _paste,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: skin.line(context)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            if (widget.controller.text.isEmpty)
              Text(
                widget.hint,
                style: skin
                    .textStyle(context, EmulatorTextRole.caption)
                    .copyWith(fontFamily: 'Menlo'),
              ),
            EditableText(
              controller: widget.controller,
              focusNode: _focus,
              style: style,
              cursorColor: skin.accent(context),
              backgroundCursorColor: skin.background(context),
              selectionColor: skin.accent(context).withValues(alpha: 0.2),
              obscureText: widget.obscure,
              onChanged: (_) => setState(() {}),
              onSubmitted: widget.onSubmitted,
            ),
          ],
        ),
      ),
    );
  }
}
