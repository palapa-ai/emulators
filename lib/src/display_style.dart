import 'dart:ui';

/// How a style degrades the sound, for looks that were also a piece of
/// hardware — the handheld's speaker is as much of the memory as its screen.
enum StyleAudio {
  clean(bits: 16, mono: false),
  handheld(bits: 8, mono: true),
  tape(bits: 10, mono: true);

  const StyleAudio({required this.bits, required this.mono});

  final int bits;
  final bool mono;
}

/// A period-correct display look applied over the emulated picture.
///
/// Every geometric value is a fraction of one *emulated* pixel rather than a
/// count of screen pixels, so a style reads identically at any output size.
enum DisplayStyle {
  vhs(
    label: 'VHS',
    shader: true,
    scanline: 0.2,
    scanlineDepth: 0.9,
    tint: Color(0xfffff4f6),
    audio: StyleAudio.tape,
  ),
  trinitron(
    label: 'Trinitron',
    scanline: 0.34,
    scanlineDepth: 0.67,
    phosphor: true,
    phosphorDepth: 0.78,
  ),
  arcade(
    label: 'Arcade',
    scanline: 0.4,
    scanlineDepth: 0.41,
    tint: Color(0xfff8ebff),
  ),
  homeTv(
    label: 'Home TV',
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
  nes(
    label: 'NES',
    nativeWidth: 256,
    nativeHeight: 240,
    scanline: 0.3,
    scanlineDepth: 0.78,
    tint: Color(0xfffdf6f0),
  ),
  gameBoy(
    label: 'Game Boy',
    nativeWidth: 160,
    nativeHeight: 144,
    pixelGap: 0.2,
    pixelGapDepth: 0.73,
    tint: Color(0xff9bcd55),
    audio: StyleAudio.handheld,
  ),
  composite(
    label: 'Composite',
    scanline: 0.25,
    scanlineDepth: 0.84,
    tint: Color(0xfffffaf2),
  );

  const DisplayStyle({
    required this.label,
    this.nativeWidth = 0,
    this.nativeHeight = 0,
    this.scanline = 0,
    this.scanlineDepth = 1,
    this.verticalStripe = 0,
    this.verticalStripeDepth = 1,
    this.pixelGap = 0,
    this.pixelGapDepth = 1,
    this.phosphorDepth = 1,
    this.tint = const Color(0xffffffff),
    this.phosphor = false,
    this.shader = false,
    this.audio = StyleAudio.clean,
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

  /// Painted by the fragment shader instead of the geometric overlay — some
  /// looks are wobble and bleed, which no amount of rectangles will fake.
  final bool shader;
  /// A look that isn't only a look — the handheld sounded like its hardware.
  final StyleAudio audio;

  /// Resolution the picture is knocked down to before it is drawn back up.
  /// Zero leaves it alone.
  final int nativeWidth;
  final int nativeHeight;

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
      final band = (fx * 3).floor().clamp(0, 2);
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
