import 'package:emulator_palapa/emulator_palapa.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AssistantPanel extends StatefulWidget {
  const AssistantPanel({
    required this.viewModel,
    required this.skin,
    super.key,
  });

  final EmulatorViewModel viewModel;
  final EmulatorSkin skin;

  @override
  State<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<AssistantPanel> {
  // The key stays in this controller for the life of the window — never
  // written to disk, never echoed into the log.
  final _url = TextEditingController();
  final _key = TextEditingController();
  final _question = TextEditingController();
  String _answer = '';
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask(String question) async {
    if (question.isEmpty || _url.text.isEmpty || _busy) return;

    widget.viewModel.assistant = HttpAssistant(
      url: _url.text,
      apiKey: _key.text,
    );

    setState(() => _busy = true);
    try {
      final answer = await widget.viewModel.askAssistant(question);
      if (mounted) setState(() => _answer = answer ?? '');
    } on Object catch (e) {
      if (mounted) setState(() => _answer = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;

    return CollapsingPanel(
      title: 'Assistant',
      trailing: [if (_busy) skin.text(context, 'thinking…', role: .caption)],
      // The panel is short and the form is not — it scrolls rather than
      // overflows, and the scroll is what tucks the title away.
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Row(
            children: [
              Expanded(
                child: _Field(hint: 'https://api…/v1', controller: _url),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Field(hint: 'API key', controller: _key, obscure: true),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Field(
            hint: 'Ask about the game…',
            controller: _question,
            onSubmitted: _ask,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final example in const [
                'make chun li fat',
                'frame generate 60fps',
                'replace yoshi with wario',
              ])
                skin.button(
                  context,
                  label: example,
                  onTap: () {
                    _question.text = example;
                    _ask(example);
                  },
                ),
            ],
          ),
          if (_answer.isNotEmpty) ...[
            const SizedBox(height: 8),
            skin.text(context, _answer, role: .caption),
          ],
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
    const style = TextStyle(
      fontFamily: 'Menlo',
      fontSize: 11,
      color: Color(0xffe8e8ee),
    );

    return GestureDetector(
      onTap: _focus.requestFocus,
      onSecondaryTap: _paste,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x33ffffff)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            if (widget.controller.text.isEmpty)
              Text(
                widget.hint,
                style: style.copyWith(color: const Color(0x44e8e8ee)),
              ),
            EditableText(
              controller: widget.controller,
              focusNode: _focus,
              style: style,
              cursorColor: const Color(0xff7fd4a8),
              backgroundCursorColor: const Color(0xff101014),
              selectionColor: const Color(0x337fd4a8),
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
