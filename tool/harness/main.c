/* Desktop harness: runs a ROM in a window without a Flutter host, so the core
   and the display styles can be exercised directly. All emulation goes through
   the same libretro_host the plugin uses. */

#include <SDL2/SDL.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#include "libretro_host.h"
#include "font.h"
#include "styles.h"

static SDL_Window *window;
static SDL_Renderer *renderer;
static SDL_Texture *frame;
static SDL_AudioDeviceID audio;
static SDL_GameController *pad;
static const uint8_t *keys;

static SDL_Texture *mask;
static int mask_w, mask_h, mask_src_w, mask_src_h, mask_style = -1;
static int style_index;
static bool style_on = true;
static uint32_t last_mouse_ms, style_shown_ms;
static float aspect = 4.0f / 3.0f;
static int frame_capacity_w, frame_capacity_h;

static SDL_Rect fit_rect(void)
{
   int w, h;
   SDL_GetRendererOutputSize(renderer, &w, &h);

   int tw = w;
   int th = (int)(w / aspect);

   if (th > h)
   {
      th = h;
      tw = (int)(h * aspect);
   }

   SDL_Rect r = { (w - tw) / 2, (h - th) / 2, tw, th };
   return r;
}

static void build_mask(int w, int h, int src_w, int src_h)
{
   if (mask && w == mask_w && h == mask_h && mask_style == style_index
         && src_w == mask_src_w && src_h == mask_src_h)
      return;

   if (mask)
      SDL_DestroyTexture(mask);

   mask_w = w;
   mask_h = h;
   mask_src_w = src_w;
   mask_src_h = src_h;
   mask_style = style_index;
   mask = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
         SDL_TEXTUREACCESS_STATIC, w, h);

   if (!mask || src_w <= 0 || src_h <= 0)
      return;

   SDL_SetTextureBlendMode(mask, SDL_BLENDMODE_MOD);

   uint32_t *px = malloc((size_t)w * h * 4);
   if (!px)
      return;

   const Style *s = &styles[style_index];
   float sx = (float)w / src_w;
   float sy = (float)h / src_h;

   for (int y = 0; y < h; y++)
   {
      float py = y / sy;
      int   gy = (int)py;
      float fy = py - gy;

      for (int x = 0; x < w; x++)
      {
         float pxx = x / sx;
         float fx = pxx - (int)pxx;
         uint8_t r, g, b;

         style_pixel(s, fx, fy, gy, &r, &g, &b);
         px[(size_t)y * w + x] =
               0xff000000u | (uint32_t)r << 16 | (uint32_t)g << 8 | b;
      }
   }

   SDL_UpdateTexture(mask, NULL, px, w * 4);
   free(px);
}

static int text_width(const char *t, int scale)
{
   return (int)strlen(t) * 6 * scale - scale;
}

static void draw_text(int x, int y, int scale, const char *t)
{
   for (const char *c = t; *c; c++, x += 6 * scale)
   {
      const uint8_t *g = glyphs[glyph_index(*c)];

      for (int row = 0; row < 7; row++)
         for (int col = 0; col < 5; col++)
            if (g[row] & 1 << (4 - col))
            {
               SDL_Rect p = { x + col * scale, y + row * scale, scale, scale };
               SDL_RenderFillRect(renderer, &p);
            }
   }
}

static SDL_Rect style_button(void)
{
   int w, h;
   SDL_GetRendererOutputSize(renderer, &w, &h);

   int bw = text_width("SHADOW MASK", 2) + 24;
   SDL_Rect r = { w - bw - 16, h - 46, bw, 30 };
   return r;
}

static bool hit_style_button(int mx, int my)
{
   int ww, wh, ow, oh;
   SDL_GetWindowSize(window, &ww, &wh);
   SDL_GetRendererOutputSize(renderer, &ow, &oh);

   if (ww <= 0 || wh <= 0)
      return false;

   SDL_Point p = { mx * ow / ww, my * oh / wh };
   SDL_Rect b = style_button();
   return SDL_PointInRect(&p, &b);
}

static void draw_style_button(void)
{
   SDL_Rect b = style_button();
   const char *label = style_on ? styles[style_index].name : "OFF";

   SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
   SDL_SetRenderDrawColor(renderer, 0, 0, 0, 170);
   SDL_RenderFillRect(renderer, &b);

   if (style_on)
      SDL_SetRenderDrawColor(renderer, 120, 230, 160, 235);
   else
      SDL_SetRenderDrawColor(renderer, 130, 130, 130, 200);

   SDL_RenderDrawRect(renderer, &b);
   draw_text(b.x + (b.w - text_width(label, 2)) / 2, b.y + 8, 2, label);
}

static void set_style(int i)
{
   style_index = i % STYLE_COUNT;
   style_on = true;
   style_shown_ms = SDL_GetTicks();
}

static void draw_style_card(void)
{
   uint32_t age = SDL_GetTicks() - style_shown_ms;
   if (age > 1600)
      return;

   const char *name = style_on ? styles[style_index].name : "FILTER OFF";
   int scale = 4;
   int tw = text_width(name, scale);
   SDL_Rect r = fit_rect();
   int x = r.x + (r.w - tw) / 2;
   int y = r.y + r.h / 2 - 14;

   uint8_t a = age > 1200 ? (uint8_t)(255 - (age - 1200) * 255 / 400) : 255;
   SDL_Rect panel = { x - 18, y - 14, tw + 36, 56 };

   SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
   SDL_SetRenderDrawColor(renderer, 0, 0, 0, (uint8_t)(a * 0.65));
   SDL_RenderFillRect(renderer, &panel);
   SDL_SetRenderDrawColor(renderer, 120, 230, 160, a);
   SDL_RenderDrawRect(renderer, &panel);
   draw_text(x, y, scale, name);
}

static void open_pad(void)
{
   if (SDL_getenv("EMU_NO_PAD"))
      return;

   if (!SDL_WasInit(SDL_INIT_GAMECONTROLLER)
         && SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER) < 0)
      return;

   for (int i = 0; i < SDL_NumJoysticks() && !pad; i++)
      if (SDL_IsGameController(i))
         pad = SDL_GameControllerOpen(i);
}

static void pump_input(EmuSession *s)
{
   static const SDL_Scancode kb[EMU_BUTTON_COUNT] = {
      [EMU_BUTTON_B] = SDL_SCANCODE_Z,     [EMU_BUTTON_Y] = SDL_SCANCODE_A,
      [EMU_BUTTON_SELECT] = SDL_SCANCODE_RSHIFT,
      [EMU_BUTTON_START] = SDL_SCANCODE_RETURN,
      [EMU_BUTTON_UP] = SDL_SCANCODE_UP,   [EMU_BUTTON_DOWN] = SDL_SCANCODE_DOWN,
      [EMU_BUTTON_LEFT] = SDL_SCANCODE_LEFT,
      [EMU_BUTTON_RIGHT] = SDL_SCANCODE_RIGHT,
      [EMU_BUTTON_A] = SDL_SCANCODE_X,     [EMU_BUTTON_X] = SDL_SCANCODE_S,
      [EMU_BUTTON_L] = SDL_SCANCODE_Q,     [EMU_BUTTON_R] = SDL_SCANCODE_W,
   };

   /* SNES face buttons sit where SDL's positional names do: B is the bottom
      button, A the right one. */
   static const SDL_GameControllerButton gp[EMU_BUTTON_COUNT] = {
      [EMU_BUTTON_B] = SDL_CONTROLLER_BUTTON_A,
      [EMU_BUTTON_Y] = SDL_CONTROLLER_BUTTON_X,
      [EMU_BUTTON_SELECT] = SDL_CONTROLLER_BUTTON_BACK,
      [EMU_BUTTON_START] = SDL_CONTROLLER_BUTTON_START,
      [EMU_BUTTON_UP] = SDL_CONTROLLER_BUTTON_DPAD_UP,
      [EMU_BUTTON_DOWN] = SDL_CONTROLLER_BUTTON_DPAD_DOWN,
      [EMU_BUTTON_LEFT] = SDL_CONTROLLER_BUTTON_DPAD_LEFT,
      [EMU_BUTTON_RIGHT] = SDL_CONTROLLER_BUTTON_DPAD_RIGHT,
      [EMU_BUTTON_A] = SDL_CONTROLLER_BUTTON_B,
      [EMU_BUTTON_X] = SDL_CONTROLLER_BUTTON_Y,
      [EMU_BUTTON_L] = SDL_CONTROLLER_BUTTON_LEFTSHOULDER,
      [EMU_BUTTON_R] = SDL_CONTROLLER_BUTTON_RIGHTSHOULDER,
   };

   for (int i = 0; i < EMU_BUTTON_COUNT; i++)
      emu_set_button(s, i, keys[kb[i]]
            || (pad && SDL_GameControllerGetButton(pad, gp[i])));
}

static void present(EmuSession *s)
{
   int w = emu_frame_width(s);
   int h = emu_frame_height(s);
   const uint32_t *pixels = emu_frame_pixels(s);

   if (w <= 0 || h <= 0 || !pixels)
      return;

   if (!frame || w > frame_capacity_w || h > frame_capacity_h)
   {
      if (frame)
         SDL_DestroyTexture(frame);
      frame_capacity_w = w > frame_capacity_w ? w : frame_capacity_w;
      frame_capacity_h = h > frame_capacity_h ? h : frame_capacity_h;
      frame = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
            SDL_TEXTUREACCESS_STREAMING, frame_capacity_w, frame_capacity_h);
   }

   SDL_Rect src = { 0, 0, w, h };
   SDL_UpdateTexture(frame, &src, pixels, w * 4);

   SDL_Rect dst = fit_rect();
   SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
   SDL_RenderClear(renderer);
   SDL_RenderCopy(renderer, frame, &src, &dst);

   if (style_on)
   {
      build_mask(dst.w, dst.h, w, h);
      if (mask)
         SDL_RenderCopy(renderer, mask, NULL, &dst);
   }

   draw_style_card();

   if (SDL_GetTicks() - last_mouse_ms < 2000)
      draw_style_button();

   SDL_RenderPresent(renderer);
}

int main(int argc, char **argv)
{
   if (argc != 3)
   {
      fprintf(stderr, "usage: %s <core.dylib> <rom>\n", argv[0]);
      return 1;
   }

   char err[512] = { 0 };
   EmuSession *s = emu_open(argv[1], argv[2], err, sizeof(err));

   if (!s)
   {
      fprintf(stderr, "%s\n", err);
      return 1;
   }

   aspect = (float)emu_aspect_ratio(s);
   fprintf(stderr, "%s %s | %.2f fps | %.0f Hz\n", emu_core_name(s),
         emu_core_version(s), emu_fps(s), emu_sample_rate(s));

   if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0)
   {
      fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
      return 1;
   }

   window = SDL_CreateWindow("emulators", SDL_WINDOWPOS_CENTERED,
         SDL_WINDOWPOS_CENTERED, 256 * 3, 224 * 3,
         SDL_WINDOW_ALLOW_HIGHDPI | SDL_WINDOW_RESIZABLE);
   renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

   SDL_AudioSpec want = {
      .freq = (int)emu_sample_rate(s), .format = AUDIO_S16SYS,
      .channels = 2, .samples = 512
   };
   audio = SDL_OpenAudioDevice(NULL, 0, &want, NULL, 0);
   SDL_PauseAudioDevice(audio, 0);

   uint32_t bytes_per_frame =
         (uint32_t)(emu_sample_rate(s) / emu_fps(s)) * 4;

   keys = SDL_GetKeyboardState(NULL);
   open_pad();
   style_shown_ms = SDL_GetTicks();

   int16_t audio_buf[8192];
   bool running = true;

   while (running)
   {
      SDL_Event e;

      while (SDL_PollEvent(&e))
      {
         if (e.type == SDL_QUIT
               || (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE))
            running = false;
         else if (e.type == SDL_CONTROLLERDEVICEADDED && !pad)
            open_pad();
         else if (e.type == SDL_CONTROLLERDEVICEREMOVED && pad)
         {
            SDL_GameControllerClose(pad);
            pad = NULL;
            open_pad();
         }
         else if (e.type == SDL_MOUSEMOTION)
            last_mouse_ms = SDL_GetTicks();
         else if (e.type == SDL_MOUSEBUTTONDOWN)
         {
            last_mouse_ms = SDL_GetTicks();
            if (hit_style_button(e.button.x, e.button.y))
               set_style(style_index + 1);
         }
         else if (e.type == SDL_KEYDOWN)
         {
            SDL_Keycode k = e.key.keysym.sym;

            if (k == SDLK_c || k == SDLK_F1)
            {
               style_on = !style_on;
               style_shown_ms = SDL_GetTicks();
            }
            else if (k == SDLK_RIGHTBRACKET)
               set_style(style_index + 1);
            else if (k == SDLK_LEFTBRACKET)
               set_style(style_index - 1 + STYLE_COUNT);
            else if (k >= SDLK_1 && k <= SDLK_9)
               set_style(k - SDLK_1);
            else if (k == SDLK_0)
               set_style(9);
            else if (k == SDLK_r)
               emu_reset(s);
         }
      }

      pump_input(s);
      emu_run_frame(s);
      present(s);

      int got = emu_audio_read(s, audio_buf, 4096);
      if (got > 0)
         SDL_QueueAudio(audio, audio_buf, (uint32_t)got * 4);

      while (SDL_GetQueuedAudioSize(audio) > bytes_per_frame * 3 && running)
         SDL_Delay(1);
   }

   if (pad)
      SDL_GameControllerClose(pad);
   if (mask)
      SDL_DestroyTexture(mask);
   if (frame)
      SDL_DestroyTexture(frame);

   SDL_CloseAudioDevice(audio);
   SDL_DestroyRenderer(renderer);
   SDL_DestroyWindow(window);
   SDL_Quit();
   emu_close(s);
   return 0;
}
