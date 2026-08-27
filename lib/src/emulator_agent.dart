import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'emulator_button.dart';
import 'emulator_session.dart';

/// One call an agent asked for, in the wire shape the assistant returns.
class AgentCall {
  const AgentCall({required this.name, this.args = const {}});

  factory AgentCall.fromJson(Map<String, dynamic> json) => AgentCall(
    name: json['name'] as String,
    args: (json['args'] as Map<String, dynamic>?) ?? const {},
  );

  final String name;
  final Map<String, dynamic> args;

  Map<String, dynamic> toJson() => {'name': name, 'args': args};
}

/// What an agent may do to the running game.
///
/// Four capabilities — memory, controls, screenshots, save states — behind
/// one named-call surface, so a model's reply can act as well as answer.
/// Every call it runs lands in the session log, where the player can see
/// exactly what the agent did.
class EmulatorAgent {
  EmulatorAgent(this._session);

  final EmulatorSession _session;

  /// The surface, by name — what an assistant is told it may ask for.
  static const api = {
    'peek': 'read [length] bytes of work RAM at [offset]',
    'poke': 'write [bytes] into work RAM at [offset]',
    'tap': 'press [button] for [frames] frames',
    'screenshot': 'the current picture as a PNG',
    'save_state': 'snapshot the whole machine',
    'load_state': 'restore the last snapshot',
  };

  Uint8List? peek(int offset, int length) {
    final ram = _session.systemRam;
    if (ram == null || offset < 0 || offset >= ram.length) return null;
    return Uint8List.sublistView(
      ram,
      offset,
      (offset + length).clamp(0, ram.length),
    );
  }

  void poke(int offset, List<int> bytes) {
    final ram = _session.systemRam;
    if (ram == null || offset < 0 || offset + bytes.length > ram.length) return;
    ram.setRange(offset, offset + bytes.length, bytes);
  }

  /// Held for a beat rather than an instant — a core polls input once per
  /// frame, and a press shorter than that is never seen.
  Future<void> tap(EmulatorButton button, {int frames = 8}) async {
    _session.press(button, pressed: true);
    await Future<void>.delayed(
      Duration(milliseconds: (frames * 1000 / 60).round()),
    );
    _session.press(button, pressed: false);
  }

  Future<Uint8List?> screenshot() async {
    final frame = _session.frames.value;
    if (frame == null) return null;
    final data = await frame.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Uint8List? _snapshot;

  bool saveState() {
    _snapshot = _session.saveState();
    return _snapshot != null;
  }

  bool loadState() {
    final snapshot = _snapshot;
    return snapshot != null && _session.loadState(snapshot);
  }

  /// Runs one named call and answers with something JSON-friendly, logging
  /// what happened where the player can see it.
  Future<Object?> run(AgentCall call) async {
    _session.log('api ${call.name}');
    switch (call.name) {
      case 'peek':
        final bytes = peek(
          call.args['offset'] as int? ?? 0,
          call.args['length'] as int? ?? 16,
        );
        return bytes == null
            ? null
            : [
                for (final b in bytes) b.toRadixString(16).padLeft(2, '0'),
              ].join(' ');
      case 'poke':
        poke(
          call.args['offset'] as int? ?? 0,
          (call.args['bytes'] as List?)?.cast<int>() ?? const [],
        );
        return true;
      case 'tap':
        final name = call.args['button'] as String? ?? '';
        final button = EmulatorButton.values
            .where((b) => b.name == name)
            .firstOrNull;
        if (button == null) return false;
        await tap(button, frames: call.args['frames'] as int? ?? 8);
        return true;
      case 'screenshot':
        final png = await screenshot();
        return png == null ? null : '${png.length} byte png';
      case 'save_state':
        return saveState();
      case 'load_state':
        return loadState();
    }
    return null;
  }
}
