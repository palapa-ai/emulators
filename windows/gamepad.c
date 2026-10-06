#include <windows.h>
#include <xinput.h>
#include "libretro_host.h"

static int read_pad(int player, XINPUT_STATE *state)
{
   if (player < 0 || player >= XUSER_MAX_COUNT) return 0;
   int connected = 0;
   for (DWORD index = 0; index < XUSER_MAX_COUNT; index++)
      if (XInputGetState(index, state) == ERROR_SUCCESS)
      {
         if (connected == player) return 1;
         connected++;
      }
   return 0;
}

EMU_API int emu_gamepad_connected_for_player(int player)
{
   XINPUT_STATE state;
   return read_pad(player, &state);
}

EMU_API const char *emu_gamepad_name_for_player(int player)
{
   return emu_gamepad_connected_for_player(player) ? "XInput controller" : NULL;
}

EMU_API uint32_t emu_gamepad_raw_for_player(int player)
{
   XINPUT_STATE state;
   if (!read_pad(player, &state)) return 0;
   WORD buttons = state.Gamepad.wButtons;
   static const WORD mapping[] = {
      XINPUT_GAMEPAD_A, XINPUT_GAMEPAD_B, XINPUT_GAMEPAD_X, XINPUT_GAMEPAD_Y,
      XINPUT_GAMEPAD_LEFT_SHOULDER, XINPUT_GAMEPAD_RIGHT_SHOULDER, 0, 0,
      XINPUT_GAMEPAD_START, XINPUT_GAMEPAD_BACK, 0,
      XINPUT_GAMEPAD_DPAD_UP, XINPUT_GAMEPAD_DPAD_DOWN,
      XINPUT_GAMEPAD_DPAD_LEFT, XINPUT_GAMEPAD_DPAD_RIGHT,
      XINPUT_GAMEPAD_LEFT_THUMB, XINPUT_GAMEPAD_RIGHT_THUMB,
   };
   uint32_t mask = 0;
   for (unsigned bit = 0; bit < sizeof(mapping) / sizeof(mapping[0]); bit++)
      if (buttons & mapping[bit]) mask |= 1u << bit;
   if (state.Gamepad.bLeftTrigger > XINPUT_GAMEPAD_TRIGGER_THRESHOLD) mask |= 1u << 6;
   if (state.Gamepad.bRightTrigger > XINPUT_GAMEPAD_TRIGGER_THRESHOLD) mask |= 1u << 7;
   return mask;
}

EMU_API uint32_t emu_gamepad_buttons_for_player(int player)
{
   uint32_t raw = emu_gamepad_raw_for_player(player);
   /* Physical positions: Xbox A is SNES B, and Xbox B is SNES A. */
   static const unsigned mapping[] = {0, 2, 9, 8, 11, 12, 13, 14, 1, 3, 4, 5};
   uint32_t mask = 0;
   for (unsigned bit = 0; bit < EMU_BUTTON_COUNT; bit++)
      if (raw & (1u << mapping[bit])) mask |= 1u << bit;
   return mask;
}
