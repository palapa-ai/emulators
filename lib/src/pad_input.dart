import 'dart:async';

import 'package:gamepads/gamepads.dart';

import 'emulator_button.dart';

/// Physical pad state, read through the `gamepads` plugin.
///
/// Keys are whatever the platform calls its elements, so the mapping is a
/// table rather than positional guesswork — and anything unrecognised is kept
/// for display, which is how an unknown pad gets mapped without a rebuild.
class PadInput {
  PadInput() {
    _subscription = Gamepads.events.listen(_onEvent);
  }

  static const _mapping = <String, EmulatorButton>{
    'a.circle': EmulatorButton.a,
    'b.circle': EmulatorButton.b,
    'x.circle': EmulatorButton.x,
    'y.circle': EmulatorButton.y,
    'button a': EmulatorButton.a,
    'button b': EmulatorButton.b,
    'button x': EmulatorButton.x,
    'button y': EmulatorButton.y,
    'l.shoulder': EmulatorButton.l,
    'r.shoulder': EmulatorButton.r,
    'left shoulder': EmulatorButton.l,
    'right shoulder': EmulatorButton.r,
    'menu': EmulatorButton.start,
    'options': EmulatorButton.select,
    'button options': EmulatorButton.select,
    'button menu': EmulatorButton.start,
    'dpad.up': EmulatorButton.up,
    'dpad.down': EmulatorButton.down,
    'dpad.left': EmulatorButton.left,
    'dpad.right': EmulatorButton.right,
    'd-pad up': EmulatorButton.up,
    'd-pad down': EmulatorButton.down,
    'd-pad left': EmulatorButton.left,
    'd-pad right': EmulatorButton.right,
  };

  StreamSubscription<GamepadEvent>? _subscription;
  int _mask = 0;

  final _seen = <String>[];

  /// Element names the pad has actually sent, newest last — the table above
  /// is only a guess until a real device says what it calls things.
  List<String> get seenKeys => List.unmodifiable(_seen);

  int get pressed => _mask;

  void _onEvent(GamepadEvent event) {
    final key = event.key.toLowerCase();

    if (!_seen.contains(key)) {
      _seen.add(key);
      if (_seen.length > 40) _seen.removeAt(0);
    }

    final button = _mapping[key];
    if (button == null) return;

    // Analog elements report a range; anything past half travel counts.
    final down = event.value.abs() > 0.5;
    final bit = 1 << button.id;
    _mask = down ? _mask | bit : _mask & ~bit;
  }

  void dispose() => unawaited(_subscription?.cancel());
}
