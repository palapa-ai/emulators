#version 460 core
#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;
uniform float uTime;
uniform vec2 uSource;
uniform vec2 uNative;
uniform vec2 uScanline;   // fraction of the emulated pixel, depth
uniform vec2 uStripe;
uniform vec2 uGap;
uniform vec2 uPhosphor;   // on/off, depth
uniform vec3 uTint;
uniform float uMode;      // 0 plain, 1 composite, 2 DMG, 3 projector, 4 OLED, 5 NES
uniform float uCurvature;
uniform float uChroma;
uniform float uVignette;
uniform sampler2D uTexture;

out vec4 fragColor;

const mat3 RGB_TO_YIQ = mat3(
  0.299,  0.596,  0.211,
  0.587, -0.274, -0.523,
  0.114, -0.322,  0.312);

const mat3 YIQ_TO_RGB = mat3(
  1.0,    1.0,    1.0,
  0.956, -0.272, -1.106,
  0.621, -0.647,  1.703);

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

// Fixed 2C02 RGB decoding of the NES's 64 color codes. Composite televisions
// vary, so this preset uses one palette and never adds off-palette CRT effects.
// Hardware color-code reference: https://www.nesdev.org/wiki/PPU_palettes
vec3 nesPalette(int index) {
  if (index == 0) return vec3(84.0, 84.0, 84.0);
  if (index == 1) return vec3(0.0, 30.0, 116.0);
  if (index == 2) return vec3(8.0, 16.0, 144.0);
  if (index == 3) return vec3(48.0, 0.0, 136.0);
  if (index == 4) return vec3(68.0, 0.0, 100.0);
  if (index == 5) return vec3(92.0, 0.0, 48.0);
  if (index == 6) return vec3(84.0, 4.0, 0.0);
  if (index == 7) return vec3(60.0, 24.0, 0.0);
  if (index == 8) return vec3(32.0, 42.0, 0.0);
  if (index == 9) return vec3(8.0, 58.0, 0.0);
  if (index == 10) return vec3(0.0, 64.0, 0.0);
  if (index == 11) return vec3(0.0, 60.0, 0.0);
  if (index == 12) return vec3(0.0, 50.0, 60.0);
  if (index == 13) return vec3(0.0, 0.0, 0.0);
  if (index == 14) return vec3(0.0, 0.0, 0.0);
  if (index == 15) return vec3(0.0, 0.0, 0.0);
  if (index == 16) return vec3(152.0, 150.0, 152.0);
  if (index == 17) return vec3(8.0, 76.0, 196.0);
  if (index == 18) return vec3(48.0, 50.0, 236.0);
  if (index == 19) return vec3(92.0, 30.0, 228.0);
  if (index == 20) return vec3(136.0, 20.0, 176.0);
  if (index == 21) return vec3(160.0, 20.0, 100.0);
  if (index == 22) return vec3(152.0, 34.0, 32.0);
  if (index == 23) return vec3(120.0, 60.0, 0.0);
  if (index == 24) return vec3(84.0, 90.0, 0.0);
  if (index == 25) return vec3(40.0, 114.0, 0.0);
  if (index == 26) return vec3(8.0, 124.0, 0.0);
  if (index == 27) return vec3(0.0, 118.0, 40.0);
  if (index == 28) return vec3(0.0, 102.0, 120.0);
  if (index == 29) return vec3(0.0, 0.0, 0.0);
  if (index == 30) return vec3(0.0, 0.0, 0.0);
  if (index == 31) return vec3(0.0, 0.0, 0.0);
  if (index == 32) return vec3(236.0, 238.0, 236.0);
  if (index == 33) return vec3(76.0, 154.0, 236.0);
  if (index == 34) return vec3(120.0, 124.0, 236.0);
  if (index == 35) return vec3(176.0, 98.0, 236.0);
  if (index == 36) return vec3(228.0, 84.0, 236.0);
  if (index == 37) return vec3(236.0, 88.0, 180.0);
  if (index == 38) return vec3(236.0, 106.0, 100.0);
  if (index == 39) return vec3(212.0, 136.0, 32.0);
  if (index == 40) return vec3(160.0, 170.0, 0.0);
  if (index == 41) return vec3(116.0, 196.0, 0.0);
  if (index == 42) return vec3(76.0, 208.0, 32.0);
  if (index == 43) return vec3(56.0, 204.0, 108.0);
  if (index == 44) return vec3(56.0, 180.0, 204.0);
  if (index == 45) return vec3(60.0, 60.0, 60.0);
  if (index == 46) return vec3(0.0, 0.0, 0.0);
  if (index == 47) return vec3(0.0, 0.0, 0.0);
  if (index == 48) return vec3(236.0, 238.0, 236.0);
  if (index == 49) return vec3(168.0, 204.0, 236.0);
  if (index == 50) return vec3(188.0, 188.0, 236.0);
  if (index == 51) return vec3(212.0, 178.0, 236.0);
  if (index == 52) return vec3(236.0, 174.0, 236.0);
  if (index == 53) return vec3(236.0, 174.0, 212.0);
  if (index == 54) return vec3(236.0, 180.0, 176.0);
  if (index == 55) return vec3(228.0, 196.0, 144.0);
  if (index == 56) return vec3(204.0, 210.0, 120.0);
  if (index == 57) return vec3(180.0, 222.0, 120.0);
  if (index == 58) return vec3(168.0, 226.0, 144.0);
  if (index == 59) return vec3(152.0, 226.0, 180.0);
  if (index == 60) return vec3(160.0, 214.0, 228.0);
  if (index == 61) return vec3(160.0, 162.0, 160.0);
  if (index == 62) return vec3(0.0, 0.0, 0.0);
  if (index == 63) return vec3(0.0, 0.0, 0.0);
  return vec3(0.0);
}

vec3 nesColor(vec3 source) {
  vec3 sampleColor = source * 255.0;
  vec3 nearest = nesPalette(0);
  float distance = 1e10;
  for (int i = 0; i < 64; i++) {
    vec3 delta = sampleColor - nesPalette(i);
    float candidate = dot(delta, delta);
    if (candidate < distance) {
      distance = candidate;
      nearest = nesPalette(i);
    }
  }
  return nearest / 255.0;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 screen = uv * 2.0 - 1.0;
  vec2 curved = screen * (1.0 + uCurvature * dot(screen, screen));
  uv = curved * 0.5 + 0.5;
  if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    return;
  }

  // The style's own grid, not the core's: an NES look reads at 256x240
  // whatever the core hands over, so sampling snaps to the style's cells.
  vec2 grid = uNative.x > 0.0 ? uNative : uSource;
  vec2 cell = uv * grid;
  vec2 f = fract(cell);
  vec2 centre = (floor(cell) + 0.5) / grid;
  float row = floor(cell.y);

  vec3 color = texture(uTexture, centre).rgb;

  if (uMode == 5.0) {
    fragColor = vec4(nesColor(color), 1.0);
    return;
  }

  if (uMode == 1.0) {
    // Composite video: brightness and colour share one wire. Luma keeps its
    // detail; chroma is smeared over neighbouring cells, and wherever the
    // brightness changes fast, the carrier misreads it as colour — the
    // rainbow on sharp edges, crawling because the phase moves every frame.
    float texel = 1.0 / grid.x;
    vec3 yiq = RGB_TO_YIQ * color;

    vec2 chroma = vec2(0.0);
    float weight = 0.0;
    for (int i = -3; i <= 3; i++) {
      float d = float(i);
      float g = exp(-(d * d) / 4.5);
      vec3 s = RGB_TO_YIQ * texture(
        uTexture, vec2(clamp(centre.x + d * texel, 0.0, 1.0), centre.y)).rgb;
      chroma += s.yz * g;
      weight += g;
    }
    yiq.yz = chroma / weight;

    float ahead = luma(texture(
      uTexture, vec2(clamp(centre.x + texel, 0.0, 1.0), centre.y)).rgb);
    float behind = luma(texture(
      uTexture, vec2(clamp(centre.x - texel, 0.0, 1.0), centre.y)).rgb);
    float edge = ahead - behind;

    // NTSC colour runs on a three-phase carrier; the fringe hue follows the
    // phase of this line this frame, which is what makes the dots crawl.
    float phase = mod(row + floor(uTime * 60.0), 3.0) * 2.0944;
    yiq.y += edge * cos(phase) * 0.18;
    yiq.z += edge * sin(phase) * 0.18;

    color = clamp(YIQ_TO_RGB * yiq, 0.0, 1.0);
  }

  if (uMode == 2.0) {
    // The DMG panel has four shades and one colour. Everything the game
    // drew collapses to a level, and the level picks a green.
    float level = floor(luma(color) * 4.0);
    level = clamp(level, 0.0, 3.0) / 3.0;
    color = mix(vec3(0.06, 0.14, 0.06), uTint, level);
  }

  if (uChroma > 0.0) {
    // Slight channel separation at the edge of the curved glass.
    vec2 offset = vec2(uChroma / grid.x, 0.0);
    color.r = mix(color.r, texture(uTexture, clamp(centre + offset, 0.0, 1.0)).r, 0.35);
    color.b = mix(color.b, texture(uTexture, clamp(centre - offset, 0.0, 1.0)).b, 0.35);
  }

  if (uMode == 3.0) {
    // A projected image has soft focus, visible grain, lamp flicker and
    // raised blacks; the light falls off toward the edge of the screen.
    vec2 texel = 1.0 / grid;
    vec3 soft = (texture(uTexture, clamp(centre + vec2(texel.x, 0.0), 0.0, 1.0)).rgb
               + texture(uTexture, clamp(centre - vec2(texel.x, 0.0), 0.0, 1.0)).rgb
               + texture(uTexture, clamp(centre + vec2(0.0, texel.y), 0.0, 1.0)).rgb
               + texture(uTexture, clamp(centre - vec2(0.0, texel.y), 0.0, 1.0)).rgb) * 0.25;
    float grain = fract(sin(dot(floor(cell) + floor(uTime * 24.0), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
    color = mix(color, soft, 0.4) * (0.96 + 0.018 * sin(uTime * 150.8));
    color = color * 0.92 + 0.035 + grain * 0.045;
  }

  if (uMode == 4.0) {
    // Clean emissive pixels: deep blacks with a restrained saturation lift.
    float grey = luma(color);
    color = max(vec3(0.0), mix(vec3(grey), color, 1.08) * 1.035 - 0.012);
  }

  float m = 1.0 - uVignette * clamp(dot(screen, screen) * 0.5, 0.0, 1.0);
  if (uScanline.x > 0.0 && f.y >= 1.0 - uScanline.x) m *= uScanline.y;
  if (uStripe.x > 0.0 && f.x >= 1.0 - uStripe.x) m *= uStripe.y;
  if (uGap.x > 0.0 && (f.x >= 1.0 - uGap.x || f.y >= 1.0 - uGap.x)) {
    m *= uGap.y;
  }

  vec3 bands = vec3(1.0);
  if (uPhosphor.x > 0.0) {
    int band = int(clamp(floor(f.x * 3.0), 0.0, 2.0));
    bands = band == 0
        ? vec3(1.0, uPhosphor.y, uPhosphor.y)
        : band == 1
            ? vec3(uPhosphor.y, 1.0, uPhosphor.y)
            : vec3(uPhosphor.y, uPhosphor.y, 1.0);
  }

  // The DMG ramp already carries the panel's colour; tinting twice would
  // green the greens.
  vec3 tint = uMode == 2.0 ? vec3(1.0) : uTint;

  fragColor = vec4(clamp(color * m * bands * tint, 0.0, 1.0), 1.0);
}
