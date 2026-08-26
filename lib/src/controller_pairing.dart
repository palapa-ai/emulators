import 'dart:io';

/// Pairing a controller is a system job; the package only knows how to get the
/// user to the place where it happens.
abstract final class ControllerPairing {
  static const _bluetoothSettings =
      'x-apple.systempreferences:com.apple.BluetoothSettings';

  /// iOS keeps its Bluetooth pane private to Settings, so there is nowhere to
  /// send the user — they pair before they reach the app.
  static bool get canOpen => Platform.isMacOS;

  static Future<void> open() async {
    if (!canOpen) return;
    await Process.run('open', [_bluetoothSettings]);
  }
}
