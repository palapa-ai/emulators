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
uniform float uMode;      // 0 plain, 1 composite video, 2 DMG panel
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

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;

  // The style's own grid, not the core's: an NES look reads at 256x240
  // whatever the core hands over, so sampling snaps to the style's cells.
  vec2 grid = uNative.x > 0.0 ? uNative : uSource;
  vec2 cell = uv * grid;
  vec2 f = fract(cell);
  vec2 centre = (floor(cell) + 0.5) / grid;
  float row = floor(cell.y);

  vec3 color = texture(uTexture, centre).rgb;

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

  float m = 1.0;
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
