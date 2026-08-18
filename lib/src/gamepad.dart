import 'dart:ffi';
import 'dart:io';

typedef _ButtonsNative = Uint32 Function();
typedef _Buttons = int Function();
typedef _ConnectedNative = Int32 Function();
typedef _Connected = int Function();

/// Reads a physical pad through Apple's GameController framework.
///
/// The mapping lives on the Swift side, which names buttons by position, so
/// nothing here has to guess what index a given device reports.
class Gamepad {
  Gamepad._(this._buttons, this._connected);

  factory Gamepad.open() {
    if (!Platform.isMacOS && !Platform.isIOS) return Gamepad._(null, null);

    final lib = DynamicLibrary.process();
    try {
      return Gamepad._(
        lib.lookupFunction<_ButtonsNative, _Buttons>('emu_gamepad_buttons'),
        lib.lookupFunction<_ConnectedNative, _Connected>(
          'emu_gamepad_connected',
        ),
      );
    } on ArgumentError {
      return Gamepad._(null, null);
    }
  }

  final _Buttons? _buttons;
  final _Connected? _connected;

  bool get isConnected => (_connected?.call() ?? 0) != 0;

  /// Bitmask indexed by [EmulatorButton]; 0 when no pad is attached.
  int get pressed => _buttons?.call() ?? 0;
}
