#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>
#include "libretro_host.h"

#define CHECK(expression) do { if (!(expression)) { \
   fprintf(stderr, "Check failed at line %d: %s\n", __LINE__, #expression); return 1; \
} } while (0)

int main(int argc, char **argv)
{
   CHECK(argc == 2);
   wchar_t temporary[MAX_PATH], directory[MAX_PATH], core[MAX_PATH], rom[MAX_PATH];
   CHECK(GetTempPathW(MAX_PATH, temporary));
   swprintf(directory, MAX_PATH, L"%lsemulator-test-%lu-\u96ea", temporary, GetCurrentProcessId());
   CHECK(CreateDirectoryW(directory, NULL));
   swprintf(core, MAX_PATH, L"%ls\\core-\u96ea.dll", directory);
   swprintf(rom, MAX_PATH, L"%ls\\game-\u96ea.rom", directory);
   wchar_t source[MAX_PATH];
   CHECK(MultiByteToWideChar(CP_UTF8, 0, argv[1], -1, source, MAX_PATH));
   CHECK(CopyFileW(source, core, FALSE));
   FILE *file = _wfopen(rom, L"wb");
   CHECK(file);
   CHECK(fwrite("test", 1, 4, file) == 4);
   fclose(file);
   char core_path[4 * MAX_PATH], rom_path[4 * MAX_PATH], error[512];
   CHECK(WideCharToMultiByte(CP_UTF8, 0, core, -1, core_path, sizeof(core_path), NULL, NULL));
   CHECK(WideCharToMultiByte(CP_UTF8, 0, rom, -1, rom_path, sizeof(rom_path), NULL, NULL));
   for (int run = 0; run < 16; run++)
   {
      EmuSession *session = emu_open(core_path, rom_path, error, sizeof(error));
      if (!session) fprintf(stderr, "%s\n", error);
      CHECK(session);
      CHECK(strcmp(emu_core_name(session), "Windows test core") == 0);
      CHECK(emu_fps(session) == 60 && emu_sample_rate(session) == 48000);
      emu_set_button(session, EMU_BUTTON_A, 1);
      emu_set_player_button(session, 1, EMU_BUTTON_B, 1);
      emu_run_frame(session);
      CHECK(emu_frame_width(session) == 2 && emu_frame_height(session) == 1);
      CHECK(emu_frame_pixels(session)[0] == 0xffff0000u);
      CHECK(emu_frame_pixels(session)[1] == 0xff00ff00u);
      CHECK(((uint8_t *)emu_ram_data(session))[1] == 1);
      CHECK(((uint8_t *)emu_ram_data(session))[2] == 1);
      CHECK(emu_audio_queued(session) == 800);
      int16_t samples[1600];
      CHECK(emu_audio_read(session, samples, 800) == 800);
      CHECK(samples[0] == 1024 && samples[1599] == 1024);
      CHECK(emu_audio_queued(session) == 0);
      uint8_t state[16];
      CHECK(emu_state_size(session) == sizeof(state));
      CHECK(emu_state_save(session, state, sizeof(state)));
      emu_run_frame(session);
      CHECK(((uint8_t *)emu_ram_data(session))[0] == 2);
      CHECK(emu_state_load(session, state, sizeof(state)));
      CHECK(((uint8_t *)emu_ram_data(session))[0] == 1);
      emu_audio_set_discard(session, 1);
      emu_run_frame(session);
      CHECK(emu_audio_queued(session) == 0);
      emu_audio_set_discard(session, 0);
      /* Hosted CI may have no output device, but starting must fail cleanly. */
      if (emu_audio_start(session) == 0) {
         emu_run_frame(session);
         Sleep(30);
         emu_audio_stop(session);
      }
      emu_close(session);
   }
   CHECK(DeleteFileW(core));
   CHECK(DeleteFileW(rom));
   CHECK(RemoveDirectoryW(directory));
   puts("Windows libretro host: Unicode paths, frames, input, audio, states and lifecycle passed");
   return 0;
}
