/// A physical control on the pad, in the bit order `emu_gamepad_raw` reports.
///
/// Raw hardware, not the SNES mapping — a remapping UI has to show what was
/// actually pressed, not what the current mapping made of it.
enum PadElement {
  a('A'),
  b('B'),
  x('X'),
  y('Y'),
  l1('L1'),
  r1('R1'),
  l2('L2'),
  r2('R2'),
  menu('MENU'),
  options('OPTIONS'),
  home('HOME'),
  up('↑'),
  down('↓'),
  left('←'),
  right('→'),
  l3('L3'),
  r3('R3');

  const PadElement(this.label);

  final String label;
}
