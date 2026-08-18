#version 460 core
#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;
uniform float uTime;
uniform sampler2D uTexture;

out vec4 fragColor;

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

  // Head switching: the drum leaves the tape near the bottom, so the last
  // few lines tear sideways and lose sync.
  float switchZone = smoothstep(0.035, 0.0, uv.y);
  float tear = (hash(vec2(field, floor(uv.y * uSize.y))) - 0.5) * switchZone * 0.05;

  // Tracking wobble, drifting down the picture rather than shaking as a whole.
  float wobble = sin(uv.y * 11.0 + uTime * 1.6) * 0.0011
               + sin(uv.y * 43.0 - uTime * 2.9) * 0.0005;

  float bandPos = fract(uTime * 0.11);
  float band = smoothstep(0.05, 0.0, abs(uv.y - bandPos));
  wobble += band * (hash(vec2(floor(uv.y * uSize.y), field)) - 0.5) * 0.007;

  vec2 warped = vec2(clamp(uv.x + wobble + tear, 0.0, 1.0), uv.y);

  // Chroma was recorded at a fraction of luma bandwidth, so it smears sideways
  // and the channels land in different places.
  float bleed = 0.0013 + band * 0.002;
  vec3 color = vec3(
    texture(uTexture, vec2(clamp(warped.x - bleed, 0.0, 1.0), warped.y)).r,
    texture(uTexture, warped).g,
    texture(uTexture, vec2(clamp(warped.x + bleed, 0.0, 1.0), warped.y)).b);

  // Luma smear trailing right off bright edges.
  vec3 trail = vec3(0.0);
  for (int i = 1; i <= 4; i++) {
    trail += texture(
      uTexture,
      vec2(clamp(warped.x - float(i) * 0.0032, 0.0, 1.0), warped.y)).rgb;
  }
  color = mix(color, color * 0.74 + trail * 0.065, 0.5);

  // Dropouts: short bright streaks where the tape lost contact. A handful of
  // lines per field, each covering part of the width.
  float line = floor(uv.y * uSize.y * 0.5);
  for (int i = 0; i < 2; i++) {
    float seed = hash1(field * 7.0 + float(i) * 131.0);
    float dropLine = floor(seed * uSize.y * 0.5);
    if (abs(line - dropLine) < 1.0) {
      float start = hash1(seed * 13.0);
      float len = 0.03 + hash1(seed * 29.0) * 0.16;
      float inStreak = step(start, uv.x) * step(uv.x, start + len);
      float sparkle = hash(vec2(floor(uv.x * uSize.x * 0.5), dropLine + field));
      color = mix(color, vec3(0.9 + sparkle * 0.1), inStreak * 0.45);
    }
  }

  // Fine tape grain, heavier in the darks like real magnetic media.
  float grain = hash(vec2(
    floor(uv.x * uSize.x * 0.5) + field * 37.0,
    floor(uv.y * uSize.y * 0.5) + field * 91.0));
  color += (grain - 0.5) * 0.025 * (1.25 - dot(color, vec3(0.333)));

  // The switching band itself: noisy, desaturated, and brighter at the seam.
  float seam = smoothstep(0.012, 0.0, uv.y);
  float switchNoise = hash(vec2(floor(uv.x * uSize.x * 0.4), field * 3.0));
  color = mix(color, vec3(switchNoise), switchZone * 0.3);
  color = mix(color, vec3(0.75 + switchNoise * 0.25), seam * 0.45);

  // Scanlines, then worn-head response: soft top end and a lifted black floor.
  color *= 1.0 - 0.05 * step(1.0, mod(floor(uv.y * uSize.y * 0.5), 2.0));
  color = pow(color, vec3(0.95));
  color = color * 0.93 + 0.04;
  color *= vec3(1.03, 0.99, 1.02);

  vec2 c = uv - 0.5;
  color *= 1.0 - dot(c, c) * 0.2;

  fragColor = vec4(color, 1.0);
}
