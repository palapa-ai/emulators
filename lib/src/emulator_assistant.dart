import 'dart:convert';
import 'dart:io';

import 'emulator_agent.dart';

/// What the assistant can see when it answers: the running game, not the
/// player's machine.
class EmulatorAssistantContext {
  const EmulatorAssistantContext({
    required this.romTitle,
    required this.system,
    required this.coreName,
    required this.logLines,
    required this.recentButtons,
    this.results = const [],
  });

  final String romTitle;
  final String system;
  final String coreName;
  final List<String> logLines;
  final List<String> recentButtons;

  /// What earlier tool calls in this exchange returned.
  final List<AgentResult> results;

  EmulatorAssistantContext after(List<AgentResult> results) =>
      EmulatorAssistantContext(
        romTitle: romTitle,
        system: system,
        coreName: coreName,
        logLines: logLines,
        recentButtons: recentButtons,
        results: results,
      );

  String get prompt =>
      'The player is inside $romTitle on the $system, emulated by $coreName. '
      'You can change the running game, not just describe it: read memory '
      'with peek, then write the bytes you want with poke. A colour, a '
      'sprite or a counter is somewhere in work RAM — find it before you '
      'write, and say what you changed. '
      'Recent inputs: ${recentButtons.join(' ')}. '
      'Emulator log:\n${logLines.join('\n')}'
      '${results.isEmpty ? '' : '\nAlready done this turn:\n'
          '${results.join('\n')}'}';
}

/// An answer, and what the model asked to do to the game alongside it.
class AssistantReply {
  const AssistantReply({required this.answer, this.calls = const []});

  final String answer;
  final List<AgentCall> calls;
}

/// The seam a host plugs a language model into.
///
/// The package knows what is on screen — the cartridge, the log, the
/// player's inputs — and nothing about any model. A host subclasses this and
/// answers however it likes; [HttpAssistant] is the plain wire-format one for
/// anything speaking the OpenAI chat shape.
abstract class EmulatorAssistant {
  Future<AssistantReply> ask(String question, EmulatorAssistantContext context);
}

/// Talks to any endpoint speaking the OpenAI chat-completions shape.
///
/// The key lives in memory for the life of the object and goes only into the
/// Authorization header of requests to [url] — never to disk, never to the
/// log.
class HttpAssistant extends EmulatorAssistant {
  HttpAssistant({required this.url, required this.apiKey, this.model = ''});

  final String url;
  final String apiKey;
  final String model;

  @override
  Future<AssistantReply> ask(
    String question,
    EmulatorAssistantContext context,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('${url.replaceFirst(RegExp(r'/+$'), '')}/chat/completions'),
      );
      request.headers
        ..contentType = ContentType.json
        ..add('Authorization', 'Bearer $apiKey');
      request.write(
        jsonEncode({
          if (model.isNotEmpty) 'model': model,
          'messages': [
            {'role': 'system', 'content': context.prompt},
            {'role': 'user', 'content': question},
          ],
          // The same context, structured — a Palapa backend reads this
          // envelope instead of parsing it back out of the prompt. Servers
          // that don't know it ignore it.
          'palapa': {
            'rom': context.romTitle,
            'system': context.system,
            'core': context.coreName,
            'inputs': context.recentButtons,
            'log': context.logLines,
            // What the model may ask for; a reply carries its requests back
            // in the same envelope as palapa.calls: [{name, args}].
            'api': EmulatorAgent.api,
          },
        }),
      );

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException('${response.statusCode}: $body', uri: request.uri);
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>;
      final message =
          (choices.first as Map<String, dynamic>)['message']
              as Map<String, dynamic>;
      final envelope = decoded['palapa'] as Map<String, dynamic>?;
      return AssistantReply(
        answer: message['content'] as String? ?? '',
        calls: [
          for (final call in (envelope?['calls'] as List?) ?? const [])
            AgentCall.fromJson(call as Map<String, dynamic>),
        ],
      );
    } finally {
      client.close();
    }
  }
}
