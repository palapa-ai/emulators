/// Buttons of the standard pad, in libretro's `RETRO_DEVICE_ID_JOYPAD` order.
enum EmulatorButton {
  b,
  y,
  select,
  start,
  up,
  down,
  left,
  right,
  a,
  x,
  l,
  r;

  int get id => index;

  String get label => switch (this) {
    EmulatorButton.up => '↑',
    EmulatorButton.down => '↓',
    EmulatorButton.left => '←',
    EmulatorButton.right => '→',
    EmulatorButton.select => 'SEL',
    EmulatorButton.start => 'START',
    _ => name.toUpperCase(),
  };
}
