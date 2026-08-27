#version 460 core
#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;
uniform float uTime;
uniform vec2 uSource;
uniform sampler2D uTexture;

out vec4 fragColor;

// VHS records colour on a separate, far narrower channel than brightness, so
// the two are split here and blurred by different amounts. Offsetting the red
// and blue channels instead only ever reads as a lens artefact.
const mat3 RGB_TO_YIQ = mat3(
  0.299,  0.596,  0.211,
  0.587, -0.274, -0.523,
  0.114, -0.322,  0.312);

const mat3 YIQ_TO_RGB = mat3(
  1.0,    1.0,    1.0,
  0.956, -0.272, -1.106,
  0.621, -0.647,  1.703);

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float hash1(float n) {
  return fract(sin(n * 91.3458) * 47453.5453);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;

  // Fields, not frames: everything below is reseeded per field so nothing
  // slides. A pattern that scrolls reads as a texture laid over the picture,
  // which is the one thing tape never looks like.
  float field = floor(uTime * 50.0);
  float line = floor(uv.y * uSource.y);

  // Head switching: the drum leaves the tape near the bottom, so the last
  // few lines tear sideways and lose sync.
  float switchZone = smoothstep(0.035, 0.0, 1.0 - uv.y);
  float tear = (hash(vec2(field, line)) - 0.5) * switchZone * 0.05;

  // Time-base error. A capstan cannot hold a line to the microsecond, so each
  // one starts a hair early or late — the picture shivers rather than sways.
  float jitter = (hash(vec2(line, field * 3.7)) - 0.5) * 0.0015;

  // Tracking wobble, drifting down the picture rather than shaking as a whole.
  float wobble = sin(uv.y * 11.0 + uTime * 1.6) * 0.0011
               + sin(uv.y * 43.0 - uTime * 2.9) * 0.0005;

  float bandPos = fract(uTime * 0.11);
  float band = smoothstep(0.05, 0.0, abs(uv.y - bandPos));
  wobble += band * (hash(vec2(line, field)) - 0.5) * 0.007;

  vec2 warped = vec2(clamp(uv.x + wobble + tear + jitter, 0.0, 1.0), uv.y);

  // Bandwidth is a property of the tape, so the taps step by source pixels and
  // the smear stays put however large the picture is drawn.
  float texel = 1.0 / uSource.x;
  vec3 sigma = vec3(0.7, 3.2, 6.4) * (1.0 + band * 1.5);

  vec3 acc = vec3(0.0);
  vec3 weight = vec3(0.0);
  float soft = 0.0;
  float softWeight = 0.0;
  vec3 lens = vec3(0.0);
  float lensWeight = 0.0;

  for (int i = -12; i <= 12; i++) {
    float d = float(i);
    vec3 rgb = texture(
      uTexture, vec2(clamp(warped.x + d * texel, 0.0, 1.0), warped.y)).rgb;
    vec3 s = RGB_TO_YIQ * rgb;

    // Luma keeps almost all of its detail, I loses most of it and Q nearly
    // all — which is why reds run on tape while edges stay legible.
    vec3 g = exp(-(d * d) / (2.0 * sigma * sigma));
    acc += s * g;
    weight += g;

    // A second, wider luma pass: the reference the peaking circuit below
    // works against.
    float gs = exp(-(d * d) / (2.0 * 2.4 * 2.4));
    soft += s.x * gs;
    softWeight += gs;

    // And the widest: the extra lens everything passed through on the way
    // to the screen, folded into the same taps.
    float gl = exp(-(d * d) / (2.0 * 3.0 * 3.0));
    lens += rgb * gl;
    lensWeight += gl;
  }

  vec3 yiq = acc / weight;

  // Every VCR oversharpens to claw back the detail the tape lost, and overdoes
  // it — the bright fringe beside hard edges is the give-away.
  yiq.x += (yiq.x - soft / softWeight) * 1.15;

  // The ring trails the edge rather than surrounding it: the circuit reacts to
  // a signal it has already passed.
  float behind = (RGB_TO_YIQ * texture(
    uTexture,
    vec2(clamp(warped.x - 2.5 * texel, 0.0, 1.0), warped.y)).rgb).x;
  yiq.x -= (behind - yiq.x) * 0.12;

  // Chroma noise sits far above luma noise on tape.
  vec2 grainSeed = vec2(
    floor(uv.x * uSource.x) + field * 37.0,
    line + field * 91.0);
  yiq.y += (hash(grainSeed) - 0.5) * 0.035;
  yiq.z += (hash(grainSeed.yx) - 0.5) * 0.035;

  vec3 color = clamp(YIQ_TO_RGB * yiq, 0.0, 1.0);

  // Dropouts: short bright streaks where the tape lost contact. A handful of
  // lines per field, each covering part of the width.
  float dropRow = floor(uv.y * uSource.y * 0.5);
  for (int i = 0; i < 2; i++) {
    float seed = hash1(field * 7.0 + float(i) * 131.0);
    float dropLine = floor(seed * uSource.y * 0.5);
    if (abs(dropRow - dropLine) < 1.0) {
      float start = hash1(seed * 13.0);
      float len = 0.03 + hash1(seed * 29.0) * 0.16;
      float inStreak = step(start, uv.x) * step(uv.x, start + len);
      float sparkle = hash(vec2(floor(uv.x * uSource.x), dropLine + field));
      color = mix(color, vec3(0.9 + sparkle * 0.1), inStreak * 0.45);
    }
  }

  // Fine tape grain, heavier in the darks like real magnetic media.
  float grain = hash(grainSeed * 1.7);
  color += (grain - 0.5) * 0.022 * (1.25 - dot(color, vec3(0.333)));

  // The switching band itself: noisy, desaturated, and brighter at the seam.
  float seam = smoothstep(0.012, 0.0, 1.0 - uv.y);
  float switchNoise = hash(vec2(floor(uv.x * uSize.x * 0.4), field * 3.0));
  color = mix(color, vec3(switchNoise), switchZone * 0.3);
  color = mix(color, vec3(0.75 + switchNoise * 0.25), seam * 0.45);

  // Interlace: each field refreshes every other line, so the one left standing
  // from the field before sits a shade darker.
  float interlace = mod(line + mod(field, 2.0), 2.0);
  color *= 1.0 - interlace * 0.055;

  // Bars where the signal is lost outright — white noise, torn sideways from
  // the picture around them. Rarer than dropouts and much taller.
  for (int i = 0; i < 2; i++) {
    float seed = hash1(field * 3.1 + float(i) * 57.0);
    if (seed > 0.86) {
      float centre = hash1(seed * 17.0);
      float height = 0.004 + hash1(seed * 41.0) * 0.02;
      float inBar = smoothstep(height, 0.0, abs(uv.y - centre));
      float bar = hash(vec2(floor(uv.x * uSource.x * 0.7), floor(centre * 300.0) + field));
      color = mix(color, vec3(0.55 + bar * 0.45), inBar * 0.65);
    }
  }

  // Everything reaching the screen has been through one more lens than it
  // should have: the picture never resolves fully sharp however good the tape.
  color = mix(color, lens / lensWeight, 0.12);

  // Scanlines, then worn-head response: soft top end and a lifted black floor.
  color *= 1.0 - 0.05 * step(1.0, mod(floor(uv.y * uSize.y * 0.5), 2.0));
  color = pow(color, vec3(0.95));
  color = color * 0.93 + 0.04;
  color *= vec3(1.03, 0.99, 1.02);

  // A tube is lit from behind its middle: the corners fall away hardest, and
  // the edges never quite reach the centre's brightness.
  float tube = uv.x * (1.0 - uv.x) * uv.y * (1.0 - uv.y);
  color *= clamp(pow(tube * 16.0, 0.22), 0.0, 1.0);

  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
