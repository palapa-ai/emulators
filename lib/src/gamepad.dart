import 'dart:ffi';
import 'dart:io';

import 'native_memory.dart';

typedef _ButtonsNative = Uint32 Function();
typedef _Buttons = int Function();
typedef _ConnectedNative = Int32 Function();
typedef _Connected = int Function();
typedef _NameNative = Pointer<Utf8> Function();
typedef _Name = Pointer<Utf8> Function();

/// Reads a physical pad through Apple's GameController framework.
///
/// The mapping lives on the Swift side, which names buttons by position, so
/// nothing here has to guess what index a given device reports.
class Gamepad {
  Gamepad._(this._buttons, this._connected, this._name, this._raw);

  factory Gamepad.open() {
    if (!Platform.isMacOS && !Platform.isIOS) {
      return Gamepad._(null, null, null, null);
    }

    final lib = DynamicLibrary.process();
    try {
      return Gamepad._(
        lib.lookupFunction<_ButtonsNative, _Buttons>('emu_gamepad_buttons'),
        lib.lookupFunction<_ConnectedNative, _Connected>(
          'emu_gamepad_connected',
        ),
        lib.lookupFunction<_NameNative, _Name>('emu_gamepad_name'),
        lib.lookupFunction<_ButtonsNative, _Buttons>('emu_gamepad_raw'),
      );
    } on ArgumentError {
      return Gamepad._(null, null, null, null);
    }
  }

  final _Buttons? _buttons;
  final _Connected? _connected;
  final _Name? _name;
  final _Buttons? _raw;

  bool get isConnected => (_connected?.call() ?? 0) != 0;

  /// Bitmask indexed by [EmulatorButton]; 0 when no pad is attached.
  int get pressed => _buttons?.call() ?? 0;

  /// Bitmask indexed by [PadElement] — what the hardware reports, before any
  /// SNES mapping is applied.
  int get rawPressed => _raw?.call() ?? 0;

  String? get name {
    final pointer = _name?.call() ?? nullptr;
    return pointer == nullptr ? null : pointer.toDart();
  }
}
