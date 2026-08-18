# emulators

Console emulation for Flutter. The package wraps [libretro](https://docs.libretro.com)
cores: a thin native host pumps frames, audio and input, and the Dart side owns
sessions, save states, display styles and the screen.

Nothing about a particular console is baked in — any libretro core works. The
one exercised so far is `snes9x2010`.

```dart
EmulatorScreen(corePath: corePath)
```

That is the whole feature: the running game over the shelf it came from,
drawn with `package:flutter/widgets.dart` only.

## Layout

```
macos/emulators/Sources/emulators_host/   libretro_host.[ch] — the native host
macos/emulators/Sources/emulators/        GameController reader
lib/src/                                  Emulator, EmulatorSession, libraries
lib/src/ui/                               screen, view model, skin, shader view
shaders/                                  vhs.frag
example/                                  the workbench
tool/harness/                             SDL harness, no Flutter at all
```

## Sessions

`EmulatorSession` drives one cartridge. It is a `ChangeNotifier`, so it needs
nothing from any state-management library.

```dart
final session = EmulatorSession(corePath: corePath)..play(rom);

session.press(EmulatorButton.start, pressed: true);
session.pause();
final state = session.saveState();
```

**Several at once.** libretro cores keep their state in globals, and dyld
returns the same image for the same path — so each session opens its own
private copy of the core. Without that, a second session silently shares the
first one's memory. `EmulatorViewModel` uses this to give every shelf card a
live picture, capped and throttled, with only the focused session audible.

## Input

Keyboard and pad are merged, never exclusive. Pads are read three ways —
GameController by name, its legacy profile, and the `gamepads` plugin —
because retro controllers disagree about what they call their own buttons.

Names a pad actually sends are reported (`session.padKeys`), so an unknown
device is mapped from what it emits rather than guessed at. Raw hardware
state is available separately from the SNES mapping, which is what a
remapping UI needs.

Sampling runs on its own timer rather than the frame loop: a paused game
still has to read its controller.

## Audio

The host plays through AudioQueue, and **emulation paces on the audio
backlog** rather than a timer. A timer runs at wall-clock rate, which is never
exactly the device's rate; the two drift and the sound crackles. Running a
frame only while the device is short of work makes the sound card the clock.

Off 1x the device can no longer be the clock — it drains at one rate — so wall
time takes over there and samples are discarded rather than queued.

## Display styles

Each style is a fraction-of-an-emulated-pixel description rather than a count
of screen pixels, so a look reads identically at any output size instead of
getting finer as the window grows.

| Style | Character |
| --- | --- |
| VHS | Tape: wobble, tracking band, chroma bleed, dropouts, head-switch tear |
| Trinitron | Aperture grille, RGB stripes, fine scanlines |
| Arcade | Tube, deep scanlines, warm |
| Horizontal | Horizontal pixels — vertical stripes |
| Dot Matrix | Square dot grid |
| NES | 256×240, scanlines |
| Game Boy | 160×144, DMG green, 8-bit mono audio |
| Composite | Soft, subtle scanlines |

VHS is a fragment shader, because none of it is geometry. Everything in it is
reseeded per field rather than scrolled: sliding noise reads as a texture laid
over the picture, which is the one thing tape never looks like.

NES and Game Boy reduce resolution for real — down then up with nearest
sampling, so the detail is gone rather than blurred. Whichever axis reduces
more sets the scale, so one lands exactly on native and the shape survives.

A style can degrade sound as well as picture: the handheld was a piece of
hardware, not only a screen.

## Skinning

The package draws plainly on purpose. A host restyles it by subclassing
`EmulatorSkin` — text, buttons, panels, cartridges — and wrapping the screen:

```dart
EmulatorTheme(
  skin: const MySkin(),
  child: EmulatorScreen(viewModel: viewModel),
)
```

Icons are *named* (`EmulatorIcon.reset`), never drawn by the package, so a
host maps them onto its own set without the package depending on one.

## Cores

Cores are not vendored. Build one and drop it beside the cartridges, or name
it explicitly:

```
git clone --depth 1 https://github.com/libretro/snes9x2010
cd snes9x2010 && make -f Makefile.libretro
```

`CoreLibrary` finds whatever is in `<root>/cores`. Note that snes9x-derived
cores carry a **non-commercial** licence; permissive cores such as `ares` are
the ones to reach for if that matters.

## Running it

```
cd example && flutter run -d macos
```

Cartridges are read from `<root>/roms`. The workbench shows the library with
live previews, the picture, a button log reporting raw controller elements,
and an activity log.

`tool/harness` runs a ROM through the same host with no Flutter at all —
useful for isolating whether a problem is in the core or the app.
