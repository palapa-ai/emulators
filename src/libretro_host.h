#ifndef LIBRETRO_HOST_H
#define LIBRETRO_HOST_H

#include <stddef.h>
#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif

#if defined(_WIN32)
#define EMU_API __declspec(dllexport)
#else
#define EMU_API __attribute__((visibility("default")))
#endif

/* libretro cores keep their state in globals and take their callbacks as
   global function pointers, so one loaded core can back exactly one session.
   emu_open fails while a session is already open. */
typedef struct EmuSession EmuSession;

enum {
   EMU_BUTTON_B = 0, EMU_BUTTON_Y, EMU_BUTTON_SELECT, EMU_BUTTON_START,
   EMU_BUTTON_UP, EMU_BUTTON_DOWN, EMU_BUTTON_LEFT, EMU_BUTTON_RIGHT,
   EMU_BUTTON_A, EMU_BUTTON_X, EMU_BUTTON_L, EMU_BUTTON_R,
   EMU_BUTTON_COUNT
};

EMU_API EmuSession *emu_open(const char *core_path, const char *rom_path,
      char *err, size_t err_len);
EMU_API void emu_close(EmuSession *s);

EMU_API void emu_run_frame(EmuSession *s);

/* Latest frame as ARGB8888, tightly packed, valid until the next run_frame. */
EMU_API const uint32_t *emu_frame_pixels(EmuSession *s);
EMU_API int emu_frame_width(EmuSession *s);
EMU_API int emu_frame_height(EmuSession *s);

/* Drains up to max_frames stereo frames; returns how many were written. */
EMU_API int emu_audio_read(EmuSession *s, int16_t *out, int max_frames);

EMU_API void emu_set_button(EmuSession *s, int button, int pressed);
EMU_API void emu_reset(EmuSession *s);

EMU_API double emu_fps(EmuSession *s);
EMU_API double emu_sample_rate(EmuSession *s);
EMU_API double emu_aspect_ratio(EmuSession *s);
EMU_API const char *emu_core_name(EmuSession *s);
EMU_API const char *emu_core_version(EmuSession *s);

EMU_API size_t emu_state_size(EmuSession *s);
EMU_API int emu_state_save(EmuSession *s, void *buf, size_t len);
EMU_API int emu_state_load(EmuSession *s, const void *buf, size_t len);

/* Battery-backed cartridge RAM; NULL/0 when the game has none. */
EMU_API size_t emu_sram_size(EmuSession *s);
EMU_API void *emu_sram_data(EmuSession *s);

#if defined(__cplusplus)
}
#endif

#endif
