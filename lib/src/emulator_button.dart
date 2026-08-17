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
}
