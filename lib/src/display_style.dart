import 'dart:ui';

/// A period-correct display look applied over the emulated picture.
///
/// Every geometric value is a fraction of one *emulated* pixel rather than a
/// count of screen pixels, so a style reads identically at any output size.
enum DisplayStyle {
  trinitron(
    label: 'Trinitron',
    scanline: 0.34,
    scanlineDepth: 0.67,
    phosphor: true,
    phosphorDepth: 0.78,
  ),
  pvm(
    label: 'PVM 20',
    scanline: 0.5,
    scanlineDepth: 0.49,
    phosphor: true,
    phosphorDepth: 0.84,
    tint: Color(0xfff8fff8),
  ),
  shadowMask(
    label: 'Shadow Mask',
    scanline: 0.34,
    scanlineDepth: 0.65,
    phosphor: true,
    phosphorDepth: 0.76,
    triad: true,
    tint: Color(0xfffffcfa),
  ),
  arcade(
    label: 'Arcade',
    scanline: 0.4,
    scanlineDepth: 0.41,
    tint: Color(0xfff8ebff),
  ),
  horizontal(
    label: 'Horizontal',
    verticalStripe: 0.34,
    verticalStripeDepth: 0.47,
    tint: Color(0xfffffcf5),
  ),
  dotMatrix(
    label: 'Dot Matrix',
    pixelGap: 0.25,
    pixelGapDepth: 0.43,
    tint: Color(0xfffafaff),
  ),
  lcd(
    label: 'LCD',
    pixelGap: 0.18,
    pixelGapDepth: 0.78,
    tint: Color(0xffe8f2ff),
  ),
  oled(label: 'OLED', pixelGap: 0.22, pixelGapDepth: 0.57),
  gameBoy(
    label: 'Game Boy',
    pixelGap: 0.2,
    pixelGapDepth: 0.73,
    tint: Color(0xff9bcd55),
  ),
  composite(
    label: 'Composite',
    scanline: 0.25,
    scanlineDepth: 0.84,
    tint: Color(0xfffffaf2),
  );

  const DisplayStyle({
    required this.label,
    this.scanline = 0,
    this.scanlineDepth = 1,
    this.verticalStripe = 0,
    this.verticalStripeDepth = 1,
    this.pixelGap = 0,
    this.pixelGapDepth = 1,
    this.phosphorDepth = 1,
    this.tint = const Color(0xffffffff),
    this.phosphor = false,
    this.triad = false,
  });

  final String label;
  final double scanline;
  final double scanlineDepth;
  final double verticalStripe;
  final double verticalStripeDepth;
  final double pixelGap;
  final double pixelGapDepth;
  final double phosphorDepth;
  final Color tint;
  final bool phosphor;
  final bool triad;

  DisplayStyle get next => values[(index + 1) % values.length];

  DisplayStyle get previous =>
      values[(index - 1 + values.length) % values.length];

  /// Multiplier for the output pixel at [fx], [fy] within the emulated pixel on
  /// row [row]. Returned channels are in 0..1 and only ever darken.
  Color sample(double fx, double fy, int row) {
    var m = 1.0;

    if (scanline > 0 && fy >= 1 - scanline) {
      m *= scanlineDepth;
    }
    if (verticalStripe > 0 && fx >= 1 - verticalStripe) {
      m *= verticalStripeDepth;
    }
    if (pixelGap > 0 && (fx >= 1 - pixelGap || fy >= 1 - pixelGap)) {
      m *= pixelGapDepth;
    }

    var r = 1.0, g = 1.0, b = 1.0;

    if (phosphor) {
      final band = triad
          ? ((fx * 3).floor().clamp(0, 2) + row) % 3
          : (fx * 3).floor().clamp(0, 2);
      switch (band) {
        case 0:
          g = b = phosphorDepth;
        case 1:
          r = b = phosphorDepth;
        default:
          r = g = phosphorDepth;
      }
    }

    return Color.from(
      alpha: 1,
      red: r * m * tint.r,
      green: g * m * tint.g,
      blue: b * m * tint.b,
    );
  }
}
