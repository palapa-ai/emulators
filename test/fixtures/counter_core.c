#include <libretro.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static retro_video_refresh_t video;
static uint32_t state[2];

static void event(const char *name)
{
   FILE *file = fopen(EVENTS_PATH, "a");
   if (file) {
      fprintf(file, "%s %u\n", name, state[1]);
      fclose(file);
   }
}

void retro_init(void) { event("open"); }
void retro_deinit(void) { event("close"); }
void retro_set_environment(retro_environment_t callback) { (void)callback; }
void retro_set_video_refresh(retro_video_refresh_t callback) { video = callback; }
void retro_set_audio_sample(retro_audio_sample_t callback) { (void)callback; }
void retro_set_audio_sample_batch(retro_audio_sample_batch_t callback) { (void)callback; }
void retro_set_input_poll(retro_input_poll_t callback) { (void)callback; }
void retro_set_input_state(retro_input_state_t callback) { (void)callback; }
void retro_get_system_info(struct retro_system_info *info)
{
   *info = (struct retro_system_info){ "Counter", "1", "sfc", false, false };
}
void retro_get_system_av_info(struct retro_system_av_info *info)
{
   *info = (struct retro_system_av_info){ { 4, 4, 4, 4, 1 }, { 60, 32000 } };
}
bool retro_load_game(const struct retro_game_info *game)
{
   state[0] = 0;
   state[1] = ((const uint8_t *)game->data)[0];
   event("load");
   return true;
}
void retro_unload_game(void) { event("unload"); }
void retro_run(void)
{
   state[0]++;
   uint16_t pixels[16];
   for (int i = 0; i < 16; i++) pixels[i] = (uint16_t)state[0];
   video(pixels, 4, 4, 8);
}
void retro_reset(void) { state[0] = 0; }
size_t retro_serialize_size(void) { return sizeof(state); }
bool retro_serialize(void *data, size_t size)
{
   if (size != sizeof(state)) return false;
   memcpy(data, state, size);
   return true;
}
bool retro_unserialize(const void *data, size_t size)
{
   if (size != sizeof(state)) return false;
   memcpy(state, data, size);
   event("restore");
   return true;
}
void *retro_get_memory_data(unsigned id)
{
   return id == RETRO_MEMORY_SYSTEM_RAM ? state : NULL;
}
size_t retro_get_memory_size(unsigned id)
{
   return id == RETRO_MEMORY_SYSTEM_RAM ? sizeof(state) : 0;
}
