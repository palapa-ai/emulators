#include <libretro.h>
#include <string.h>

static retro_environment_t environment;
static retro_video_refresh_t video;
static retro_audio_sample_batch_t audio;
static retro_input_state_t input;
static uint8_t memory[16];

void retro_set_environment(retro_environment_t callback) { environment = callback; }
void retro_set_video_refresh(retro_video_refresh_t callback) { video = callback; }
void retro_set_audio_sample(retro_audio_sample_t callback) { (void)callback; }
void retro_set_audio_sample_batch(retro_audio_sample_batch_t callback) { audio = callback; }
void retro_set_input_poll(retro_input_poll_t callback) { (void)callback; }
void retro_set_input_state(retro_input_state_t callback) { input = callback; }
void retro_init(void) {
   enum retro_pixel_format format = RETRO_PIXEL_FORMAT_XRGB8888;
   environment(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &format);
   memset(memory, 0, sizeof(memory));
}
void retro_deinit(void) {}
unsigned retro_api_version(void) { return RETRO_API_VERSION; }
void retro_get_system_info(struct retro_system_info *info) {
   memset(info, 0, sizeof(*info));
   info->library_name = "Windows test core";
   info->library_version = "1";
   info->valid_extensions = "rom";
}
void retro_get_system_av_info(struct retro_system_av_info *info) {
   memset(info, 0, sizeof(*info));
   info->geometry.base_width = info->geometry.max_width = 2;
   info->geometry.base_height = info->geometry.max_height = 1;
   info->geometry.aspect_ratio = 2;
   info->timing.fps = 60;
   info->timing.sample_rate = 48000;
}
void retro_set_controller_port_device(unsigned port, unsigned device) { (void)port; (void)device; }
void retro_reset(void) { memset(memory, 0, sizeof(memory)); }
void retro_run(void) {
   uint32_t pixels[] = {0x00ff0000, 0x0000ff00};
   int16_t samples[1600];
   for (int i = 0; i < 1600; i++) samples[i] = 1024;
   memory[0]++;
   memory[1] = (uint8_t)input(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A);
   memory[2] = (uint8_t)input(1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B);
   video(pixels, 2, 1, sizeof(pixels));
   audio(samples, 800);
}
size_t retro_serialize_size(void) { return sizeof(memory); }
bool retro_serialize(void *data, size_t size) {
   if (size != sizeof(memory)) return false;
   memcpy(data, memory, size);
   return true;
}
bool retro_unserialize(const void *data, size_t size) {
   if (size != sizeof(memory)) return false;
   memcpy(memory, data, size);
   return true;
}
void retro_cheat_reset(void) {}
void retro_cheat_set(unsigned index, bool enabled, const char *code) { (void)index; (void)enabled; (void)code; }
bool retro_load_game(const struct retro_game_info *game) { return game && game->size == 4; }
bool retro_load_game_special(unsigned type, const struct retro_game_info *games, size_t count) { (void)type; (void)games; (void)count; return false; }
void retro_unload_game(void) {}
unsigned retro_get_region(void) { return RETRO_REGION_NTSC; }
void *retro_get_memory_data(unsigned id) { (void)id; return memory; }
size_t retro_get_memory_size(unsigned id) { (void)id; return sizeof(memory); }
