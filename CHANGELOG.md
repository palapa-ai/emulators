## 0.1.0

- Every display style is a fragment shader: composite fringing that crawls,
  the DMG's four greens, and the tape's own pass
- Work RAM through the host, and a live hex view of it
- `EmulatorAssistant` — a seam for a language model, with `HttpAssistant` for
  anything speaking the OpenAI chat shape
- `EmulatorAgent` — memory, controls, screenshots and save states, so a model
  can act on the game rather than only describe it
- Fullscreen: the picture alone, controls that leave with the pointer
- Cartridges arrive by drag and drop; the shelf keeps a played game where it
  was left and runs only the ones never opened
- Cupertino glyph outlines, still no dependencies

## 0.0.1

- libretro host: frames, audio, input, save states, cartridge RAM
- Concurrent sessions, each with its own copy of the core
- Keyboard and controller input, merged
- AudioQueue playback paced on the audio backlog
- Eight display styles, VHS as a fragment shader
- `EmulatorSkin` for host restyling
- SDL harness and a Flutter workbench
