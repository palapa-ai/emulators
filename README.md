# emulators

Console emulation for Palapa. The package wraps [libretro](https://docs.libretro.com)
cores: the native side is a thin host that pumps frames, audio and input, and
the Dart side owns sessions, save states and the display styles.

Nothing about the emulated system is hard-coded — any libretro core works. The
one exercised so far is `snes9x2010` (SNES).

## Layout

```
src/                 libretro_host.[ch] — the native host, no windowing
lib/src/             Emulator, DisplayStyle, FFI bindings
tool/harness/        SDL desktop harness: run a ROM without a Flutter host
macos/, ios/         podspecs (ffiPlugin)
```

## Using it

```dart
final emulator = Emulator.open(corePath: corePath, romPath: romPath);

emulator.setButton(EmulatorButton.start, pressed: true);
emulator.runFrame();

final pixels = emulator.frame;          // ARGB8888, aliases native memory
final audio = emulator.readAudio();     // interleaved stereo 16-bit

final state = emulator.saveState();
emulator.close();
```

`Emulator.frame` returns a view onto native memory that the next `runFrame`
overwrites. Copy it if it needs to outlive the frame.

**One session per process.** libretro cores keep their state in globals and
take their callbacks as global function pointers, so a second `Emulator.open`
throws while one is alive. That is a property of libretro, not of this package.

## Display styles

Ten looks, each a fraction-of-an-emulated-pixel description rather than a count
of screen pixels — so a style reads identically at any output size instead of
getting finer as the window grows.

| Style | Character |
| --- | --- |
| Trinitron | Sony aperture grille, RGB stripes, fine scanlines |
| PVM 20 | Broadcast monitor, heavy 50% scanlines |
| Shadow Mask | Consumer CRT, triads staggered per row |
| Arcade | Tube, deepest scanlines, warm |
| Horizontal | Horizontal pixels — vertical stripes |
| Dot Matrix | Square dot grid, wide gaps |
| LCD | Tight grid, cool tint |
| OLED | Deep pixel gaps, neutral |
| Game Boy | DMG green, dot grid |
| Composite | Soft, subtle scanlines, warm |

`DisplayStyle.sample(fx, fy, row)` returns the multiplier for one output pixel.
Styles only ever darken or tint, never brighten.

## Harness

Runs a ROM in a window with no Flutter host, for exercising cores and styles:

```
cd tool/harness && make
./harness /path/to/core.dylib /path/to/rom.sfc
```

Arrows move; `Z`/`X` are B/A, `A`/`S` are Y/X, `Q`/`W` are L/R, Return is Start,
right Shift is Select. `[` and `]` cycle styles, `1`–`9` and `0` pick one, `C`
toggles the filter, `R` resets, Escape quits. A game controller is picked up
automatically; `EMU_NO_PAD=1` skips that.

Requires SDL2 (`brew install sdl2`). The harness is a development tool — the
package itself has no SDL dependency.

## Cores

Cores are not vendored. Build one and point the package at the `.dylib`:

```
git clone --depth 1 https://github.com/libretro/snes9x2010
cd snes9x2010 && make -f Makefile.libretro
```

Note that snes9x-derived cores carry a **non-commercial** licence. Cores with
permissive terms (for example `ares`) are the ones to reach for if that
matters.
