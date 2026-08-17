# emulators example

Runs the package on its own, with its default skin — no design system, plain
text and taps.

```
flutter run -d macos --dart-define=CORE=/path/to/snes9x2010_libretro.dylib
```

Cartridges are read from `roms/` under the current directory; pass
`--dart-define=LIBRARY=/some/folder` to keep them somewhere else. Without a
`CORE` the screen still runs and says no core is bundled.
