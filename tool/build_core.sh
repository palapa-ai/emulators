#!/usr/bin/env bash
# Builds a libretro core and installs it where the package looks for cores.
# Cores are not vendored — this fetches and compiles one on demand.
set -euo pipefail

CORE="${1:-snes9x2010}"
DEST="${CORE_DIR:-$HOME/Library/Application Support/ai.palapa.app/cores}"
DYLIB="$DEST/${CORE}_libretro.dylib"

if [[ -f "$DYLIB" && -z "${FORCE:-}" ]]; then
  echo "core present: $DYLIB"
  exit 0
fi

WORK="$(cd "$(dirname "$0")" && pwd)/.cores/$CORE"
mkdir -p "$(dirname "$WORK")"

if [[ ! -d "$WORK" ]]; then
  git clone --depth 1 "https://github.com/libretro/$CORE" "$WORK"
fi

make -C "$WORK" -f Makefile.libretro -j"$(sysctl -n hw.ncpu)"

mkdir -p "$DEST"
cp "$WORK/${CORE}_libretro.dylib" "$DYLIB"
echo "installed: $DYLIB"
