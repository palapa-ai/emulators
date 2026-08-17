#!/bin/bash
cd "$(dirname "$0")"
./harness "$HOME/dev/snes9x2010/snes9x2010_libretro.dylib" "$@" 2>&1 | tee /tmp/emu-harness.log
