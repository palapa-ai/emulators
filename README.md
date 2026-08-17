# emulators

Console emulation for Palapa. The package wraps [libretro](https://docs.libretro.com)
cores: the native side is a thin host that pumps frames, audio and input, and
the Dart side owns sessions, save states and the display styles.

Nothing about the emulated system is hard-coded — any libretro core works. The
one exercised so far is `snes9x2010` (SNES).

## Layout

```
macos/emulators/Sources/emulators/  libretro_host.[ch] — the native host
lib/src/             Emulator, EmulatorSession, RomLibrary, FFI bindings
lib/src/ui/          EmulatorScreen and the skin that draws it
example/             runs the package on its own
tool/harness/        SDL harness: run a ROM with no Flutter at all
macos/, ios/         Package.swift + podspec (ffiPlugin)
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

## The screen

`EmulatorScreen` is the whole feature — the running game over the shelf it came
from. It draws with `package:flutter/widgets.dart` only: plain text and taps,
no design system, so it runs on its own.

```dart
EmulatorScreen(corePath: corePath)
```

A host restyles it by subclassing `EmulatorSkin` and wrapping the screen —
nothing about the host's design system reaches the package:

```dart
EmulatorTheme(
  skin: const MySkin(),          // override text/button/cartridge
  child: EmulatorScreen(corePath: corePath),
)
```

`EmulatorScreenState.addFiles` and `.refresh` let a host add cartridges its own
way — a drop target, a file picker — without the package taking on those
dependencies.

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
