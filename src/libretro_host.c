#include "libretro_host.h"

#include <dlfcn.h>
#include <stdarg.h>
#include <libretro.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define AUDIO_CAPACITY 65536

struct EmuSession {
   void *lib;

   void (*init)(void);
   void (*deinit)(void);
   void (*set_environment)(retro_environment_t);
   void (*set_video_refresh)(retro_video_refresh_t);
   void (*set_audio_sample)(retro_audio_sample_t);
   void (*set_audio_sample_batch)(retro_audio_sample_batch_t);
   void (*set_input_poll)(retro_input_poll_t);
   void (*set_input_state)(retro_input_state_t);
   void (*get_system_info)(struct retro_system_info *);
   void (*get_system_av_info)(struct retro_system_av_info *);
   bool (*load_game)(const struct retro_game_info *);
   void (*unload_game)(void);
   void (*run)(void);
   void (*reset)(void);
   size_t (*serialize_size)(void);
   bool (*serialize)(void *, size_t);
   bool (*unserialize)(const void *, size_t);
   void *(*get_memory_data)(unsigned);
   size_t (*get_memory_size)(unsigned);

   void *rom;
   unsigned pixel_format;

   uint32_t *pixels;
   int frame_w, frame_h, pixel_capacity;

   int16_t *audio;
   int audio_count;

   int16_t buttons[EMU_BUTTON_COUNT];

   struct retro_system_info info;
   struct retro_system_av_info av;

   char system_dir[1024];
};

/* The core's callbacks carry no user pointer, so the active session has to be
   reachable from file scope. */
static EmuSession *active;

static void cb_log(enum retro_log_level level, const char *fmt, ...)
{
   va_list ap;
   (void)level;
   va_start(ap, fmt);
   vfprintf(stderr, fmt, ap);
   va_end(ap);
}

static bool cb_environment(unsigned cmd, void *data)
{
   if (!active)
      return false;

   switch (cmd)
   {
      case RETRO_ENVIRONMENT_GET_CAN_DUPE:
         *(bool *)data = true;
         return true;

      case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
         active->pixel_format = *(const enum retro_pixel_format *)data;
         return true;

      case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
      case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
         *(const char **)data = active->system_dir;
         return true;

      case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:
         ((struct retro_log_callback *)data)->log = cb_log;
         return true;

      case RETRO_ENVIRONMENT_GET_VARIABLE:
         ((struct retro_variable *)data)->value = NULL;
         return false;

      case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
         *(bool *)data = false;
         return true;

      case RETRO_ENVIRONMENT_SET_VARIABLES:
      case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
      case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
      case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
      case RETRO_ENVIRONMENT_SET_MEMORY_MAPS:
      case RETRO_ENVIRONMENT_SET_GEOMETRY:
         return true;

      default:
         return false;
   }
}

static void cb_video(const void *data, unsigned width, unsigned height,
      size_t pitch)
{
   if (!active || !data)
      return;

   int need = (int)(width * height);

   if (need > active->pixel_capacity)
   {
      uint32_t *grown = realloc(active->pixels, (size_t)need * 4);
      if (!grown)
         return;
      active->pixels = grown;
      active->pixel_capacity = need;
   }

   active->frame_w = (int)width;
   active->frame_h = (int)height;

   for (unsigned y = 0; y < height; y++)
   {
      const uint8_t *row = (const uint8_t *)data + (size_t)y * pitch;
      uint32_t *out = active->pixels + (size_t)y * width;

      for (unsigned x = 0; x < width; x++)
      {
         uint8_t r, g, b;

         if (active->pixel_format == RETRO_PIXEL_FORMAT_RGB565)
         {
            uint16_t p = ((const uint16_t *)row)[x];
            r = (uint8_t)((p >> 11 & 0x1f) << 3);
            g = (uint8_t)((p >> 5 & 0x3f) << 2);
            b = (uint8_t)((p & 0x1f) << 3);
         }
         else if (active->pixel_format == RETRO_PIXEL_FORMAT_XRGB8888)
         {
            uint32_t p = ((const uint32_t *)row)[x];
            r = (uint8_t)(p >> 16);
            g = (uint8_t)(p >> 8);
            b = (uint8_t)p;
         }
         else
         {
            uint16_t p = ((const uint16_t *)row)[x];
            r = (uint8_t)((p >> 10 & 0x1f) << 3);
            g = (uint8_t)((p >> 5 & 0x1f) << 3);
            b = (uint8_t)((p & 0x1f) << 3);
         }

         out[x] = 0xff000000u | (uint32_t)r << 16 | (uint32_t)g << 8 | b;
      }
   }
}

static void push_audio(const int16_t *data, size_t frames)
{
   if (!active)
      return;

   int room = AUDIO_CAPACITY / 2 - active->audio_count;
   int take = (int)frames < room ? (int)frames : room;

   if (take <= 0)
      return;

   memcpy(active->audio + (size_t)active->audio_count * 2, data,
         (size_t)take * 4);
   active->audio_count += take;
}

static size_t cb_audio_batch(const int16_t *data, size_t frames)
{
   push_audio(data, frames);
   return frames;
}

static void cb_audio_sample(int16_t left, int16_t right)
{
   int16_t f[2] = { left, right };
   push_audio(f, 1);
}

static void cb_input_poll(void) { }

static int16_t cb_input_state(unsigned port, unsigned device, unsigned index,
      unsigned id)
{
   (void)index;

   if (!active || port != 0 || device != RETRO_DEVICE_JOYPAD
         || id >= EMU_BUTTON_COUNT)
      return 0;

   return active->buttons[id];
}

static void *sym(void *lib, const char *name)
{
   return dlsym(lib, name);
}

static void fail(char *err, size_t err_len, const char *msg)
{
   if (err && err_len)
      snprintf(err, err_len, "%s", msg);
}

EmuSession *emu_open(const char *core_path, const char *rom_path,
      char *err, size_t err_len)
{
   if (active)
   {
      fail(err, err_len, "a session is already open");
      return NULL;
   }

   EmuSession *s = calloc(1, sizeof(*s));
   if (!s)
   {
      fail(err, err_len, "out of memory");
      return NULL;
   }

   s->pixel_format = RETRO_PIXEL_FORMAT_0RGB1555;
   snprintf(s->system_dir, sizeof(s->system_dir), ".");

   s->lib = dlopen(core_path, RTLD_LAZY);
   if (!s->lib)
   {
      fail(err, err_len, dlerror());
      free(s);
      return NULL;
   }

   s->init                   = sym(s->lib, "retro_init");
   s->deinit                 = sym(s->lib, "retro_deinit");
   s->set_environment        = sym(s->lib, "retro_set_environment");
   s->set_video_refresh      = sym(s->lib, "retro_set_video_refresh");
   s->set_audio_sample       = sym(s->lib, "retro_set_audio_sample");
   s->set_audio_sample_batch = sym(s->lib, "retro_set_audio_sample_batch");
   s->set_input_poll         = sym(s->lib, "retro_set_input_poll");
   s->set_input_state        = sym(s->lib, "retro_set_input_state");
   s->get_system_info        = sym(s->lib, "retro_get_system_info");
   s->get_system_av_info     = sym(s->lib, "retro_get_system_av_info");
   s->load_game              = sym(s->lib, "retro_load_game");
   s->unload_game            = sym(s->lib, "retro_unload_game");
   s->run                    = sym(s->lib, "retro_run");
   s->reset                  = sym(s->lib, "retro_reset");
   s->serialize_size         = sym(s->lib, "retro_serialize_size");
   s->serialize              = sym(s->lib, "retro_serialize");
   s->unserialize            = sym(s->lib, "retro_unserialize");
   s->get_memory_data        = sym(s->lib, "retro_get_memory_data");
   s->get_memory_size        = sym(s->lib, "retro_get_memory_size");

   if (!s->init || !s->load_game || !s->run || !s->get_system_av_info)
   {
      fail(err, err_len, "not a libretro core: missing entry points");
      dlclose(s->lib);
      free(s);
      return NULL;
   }

   s->audio = malloc(AUDIO_CAPACITY * sizeof(int16_t));
   if (!s->audio)
   {
      fail(err, err_len, "out of memory");
      dlclose(s->lib);
      free(s);
      return NULL;
   }

   active = s;

   s->set_environment(cb_environment);
   s->init();
   s->set_video_refresh(cb_video);
   s->set_audio_sample(cb_audio_sample);
   s->set_audio_sample_batch(cb_audio_batch);
   s->set_input_poll(cb_input_poll);
   s->set_input_state(cb_input_state);

   FILE *f = fopen(rom_path, "rb");
   if (!f)
   {
      fail(err, err_len, "cannot open rom");
      emu_close(s);
      return NULL;
   }

   fseek(f, 0, SEEK_END);
   size_t size = (size_t)ftell(f);
   fseek(f, 0, SEEK_SET);
   s->rom = malloc(size);

   if (!s->rom || fread(s->rom, 1, size, f) != size)
   {
      fclose(f);
      fail(err, err_len, "cannot read rom");
      emu_close(s);
      return NULL;
   }

   fclose(f);

   struct retro_game_info game = { rom_path, s->rom, size, NULL };

   if (!s->load_game(&game))
   {
      fail(err, err_len, "core rejected the rom");
      emu_close(s);
      return NULL;
   }

   s->get_system_info(&s->info);
   s->get_system_av_info(&s->av);
   return s;
}

void emu_close(EmuSession *s)
{
   if (!s)
      return;

   if (s->unload_game)
      s->unload_game();
   if (s->deinit)
      s->deinit();
   if (s->lib)
      dlclose(s->lib);

   free(s->rom);
   free(s->pixels);
   free(s->audio);

   if (active == s)
      active = NULL;

   free(s);
}

void emu_run_frame(EmuSession *s)
{
   if (s && s->run)
      s->run();
}

const uint32_t *emu_frame_pixels(EmuSession *s) { return s ? s->pixels : NULL; }
int emu_frame_width(EmuSession *s)  { return s ? s->frame_w : 0; }
int emu_frame_height(EmuSession *s) { return s ? s->frame_h : 0; }

int emu_audio_read(EmuSession *s, int16_t *out, int max_frames)
{
   if (!s || !out || max_frames <= 0)
      return 0;

   int take = s->audio_count < max_frames ? s->audio_count : max_frames;
   memcpy(out, s->audio, (size_t)take * 4);

   int left = s->audio_count - take;
   if (left > 0)
      memmove(s->audio, s->audio + (size_t)take * 2, (size_t)left * 4);

   s->audio_count = left;
   return take;
}

void emu_set_button(EmuSession *s, int button, int pressed)
{
   if (s && button >= 0 && button < EMU_BUTTON_COUNT)
      s->buttons[button] = pressed ? 1 : 0;
}

void emu_reset(EmuSession *s)
{
   if (s && s->reset)
      s->reset();
}

double emu_fps(EmuSession *s) { return s ? s->av.timing.fps : 0.0; }
double emu_sample_rate(EmuSession *s) { return s ? s->av.timing.sample_rate : 0.0; }

double emu_aspect_ratio(EmuSession *s)
{
   if (!s || s->av.geometry.aspect_ratio <= 0.0f)
      return 4.0 / 3.0;
   return s->av.geometry.aspect_ratio;
}

const char *emu_core_name(EmuSession *s)
{
   return s && s->info.library_name ? s->info.library_name : "";
}

const char *emu_core_version(EmuSession *s)
{
   return s && s->info.library_version ? s->info.library_version : "";
}

size_t emu_state_size(EmuSession *s)
{
   return s && s->serialize_size ? s->serialize_size() : 0;
}

int emu_state_save(EmuSession *s, void *buf, size_t len)
{
   return s && s->serialize && s->serialize(buf, len) ? 1 : 0;
}

int emu_state_load(EmuSession *s, const void *buf, size_t len)
{
   return s && s->unserialize && s->unserialize(buf, len) ? 1 : 0;
}

size_t emu_sram_size(EmuSession *s)
{
   return s && s->get_memory_size
         ? s->get_memory_size(RETRO_MEMORY_SAVE_RAM) : 0;
}

void *emu_sram_data(EmuSession *s)
{
   return s && s->get_memory_data
         ? s->get_memory_data(RETRO_MEMORY_SAVE_RAM) : NULL;
}
