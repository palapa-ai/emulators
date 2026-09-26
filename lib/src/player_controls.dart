import 'package:flutter/foundation.dart';

import 'emulator_button.dart';

enum EmulatorPlayer {
  p1(0, 'P1'),
  p2(1, 'P2');

  const EmulatorPlayer(this.port, this.label);
  final int port;
  final String label;
}

enum ControllerDriver {
  human('Human'),
  ai('AI');

  const ControllerDriver(this.label);
  final String label;
}

class PlayerControls extends ChangeNotifier {
  PlayerControls(this.player);

  final EmulatorPlayer player;
  ControllerDriver _driver = .human;
  int _held = 0;
  final _history = <EmulatorButton>[];

  ControllerDriver get driver => _driver;
  int get held => _held;
  String get label => '${driver.label} ${player.label}';
  List<EmulatorButton> get history => List.unmodifiable(_history);

  void assign(ControllerDriver driver) {
    if (_driver == driver) return;
    _driver = driver;
    _held = 0;
    _history.clear();
    notifyListeners();
  }

  void update(ControllerDriver source, int mask, {bool record = true}) {
    if (source != driver) return;
    final valid = mask & ((1 << EmulatorButton.values.length) - 1);
    if (_held == valid) return;
    final pressed = valid & ~_held;
    _held = valid;
    if (record) {
      _history.addAll(
        EmulatorButton.values.where((b) => pressed & (1 << b.id) != 0),
      );
      if (_history.length > 120) _history.removeRange(0, _history.length - 120);
    }
    notifyListeners();
  }

  void release() => update(driver, 0, record: false);

  void reset() {
    _held = 0;
    _history.clear();
    notifyListeners();
  }
}
