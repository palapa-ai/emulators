import 'dart:ffi';
import 'dart:io';

import 'native_memory.dart';
import 'player_controls.dart';

typedef _ButtonsNative = Uint32 Function(Int32);
typedef _Buttons = int Function(int);
typedef _ConnectedNative = Int32 Function(Int32);
typedef _Connected = int Function(int);
typedef _NameNative = Pointer<Utf8> Function(Int32);
typedef _Name = Pointer<Utf8> Function(int);

/// Reads a physical pad through Apple's GameController framework.
///
/// The mapping lives on the Swift side, which names buttons by position, so
/// nothing here has to guess what index a given device reports.
class Gamepad {
  Gamepad._(this.player, this._buttons, this._connected, this._name, this._raw);

  final EmulatorPlayer player;

  factory Gamepad.open({EmulatorPlayer player = .p1}) {
    if (!Platform.isMacOS && !Platform.isIOS) {
      return Gamepad._(player, null, null, null, null);
    }

    final lib = DynamicLibrary.process();
    try {
      return Gamepad._(
        player,
        lib.lookupFunction<_ButtonsNative, _Buttons>(
          'emu_gamepad_buttons_for_player',
        ),
        lib.lookupFunction<_ConnectedNative, _Connected>(
          'emu_gamepad_connected_for_player',
        ),
        lib.lookupFunction<_NameNative, _Name>('emu_gamepad_name_for_player'),
        lib.lookupFunction<_ButtonsNative, _Buttons>(
          'emu_gamepad_raw_for_player',
        ),
      );
    } on ArgumentError {
      return Gamepad._(player, null, null, null, null);
    }
  }

  final _Buttons? _buttons;
  final _Connected? _connected;
  final _Name? _name;
  final _Buttons? _raw;

  bool get isConnected => (_connected?.call(player.port) ?? 0) != 0;

  /// Bitmask indexed by [EmulatorButton]; 0 when no pad is attached.
  int get pressed => _buttons?.call(player.port) ?? 0;

  /// Bitmask indexed by [PadElement] — what the hardware reports, before any
  /// SNES mapping is applied.
  int get rawPressed => _raw?.call(player.port) ?? 0;

  String? get name {
    final pointer = _name?.call(player.port) ?? nullptr;
    return pointer == nullptr ? null : pointer.toDart();
  }
}
