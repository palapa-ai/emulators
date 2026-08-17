SDL  := $(lastword $(sort $(wildcard /opt/homebrew/Cellar/sdl2/*)))
SRC  := ../../macos/emulators/Sources/emulators

CFLAGS  := -O2 -Wall -Wextra -std=c11 -I$(SDL)/include -I$(SRC)/include
LDFLAGS := -L$(SDL)/lib -lSDL2

harness: main.c $(SRC)/libretro_host.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f harness

.PHONY: clean
