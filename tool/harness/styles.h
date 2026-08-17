#ifndef STYLES_H
#define STYLES_H

#include <stdbool.h>
#include <stdint.h>

/* Every geometry value is a fraction of one *emulated* pixel, never a count of
   screen pixels, so a style looks identical at any window size. */
typedef struct {
   const char *name;
   float scan_frac;    int scan_dark;
   float vstripe_frac; int vstripe_dark;
   float grid_frac;    int grid_dark;
   int   rgb_dark;
   uint8_t tint_r, tint_g, tint_b;
   bool rgb, triad;
} Style;

static const Style styles[] = {
   { "TRINITRON",   0.34f, 170, 0.0f,   0, 0.00f,   0, 200, 255, 255, 255, true,  false },
   { "PVM 20",      0.50f, 125, 0.0f,   0, 0.00f,   0, 215, 248, 255, 248, true,  false },
   { "SHADOW MASK", 0.34f, 165, 0.0f,   0, 0.00f,   0, 195, 255, 252, 250, true,  true  },
   { "ARCADE",      0.40f, 105, 0.0f,   0, 0.00f,   0,   0, 255, 248, 235, false, false },
   { "HORIZONTAL",  0.00f,   0, 0.34f, 120, 0.00f,  0,   0, 255, 252, 245, false, false },
   { "DOT MATRIX",  0.00f,   0, 0.0f,   0, 0.25f, 110,   0, 250, 250, 255, false, false },
   { "LCD",         0.00f,   0, 0.0f,   0, 0.18f, 200,   0, 232, 242, 255, false, false },
   { "OLED",        0.00f,   0, 0.0f,   0, 0.22f, 145,   0, 255, 255, 255, false, false },
   { "GAME BOY",    0.00f,   0, 0.0f,   0, 0.20f, 185,   0, 155, 205,  85, false, false },
   { "COMPOSITE",   0.25f, 215, 0.0f,   0, 0.00f,   0,   0, 255, 250, 242, false, false },
};

#define STYLE_COUNT ((int)(sizeof(styles) / sizeof(*styles)))

/* fx/fy are the position within the current emulated pixel in [0,1);
   gy is its row index, used to stagger shadow-mask triads. */
static void style_pixel(const Style *s, float fx, float fy, int gy,
      uint8_t *out_r, uint8_t *out_g, uint8_t *out_b)
{
   int m = 255, r = 255, g = 255, b = 255;

   if (s->scan_frac > 0.0f && fy >= 1.0f - s->scan_frac)
      m = s->scan_dark;

   if (s->vstripe_frac > 0.0f && fx >= 1.0f - s->vstripe_frac)
      m = m * s->vstripe_dark / 255;

   if (s->grid_frac > 0.0f
         && (fx >= 1.0f - s->grid_frac || fy >= 1.0f - s->grid_frac))
      m = m * s->grid_dark / 255;

   if (s->rgb)
   {
      int band = (int)(fx * 3.0f);
      if (band > 2)
         band = 2;
      if (s->triad)
         band = (band + gy) % 3;

      switch (band)
      {
         case 0:  g = b = s->rgb_dark; break;
         case 1:  r = b = s->rgb_dark; break;
         default: r = g = s->rgb_dark; break;
      }
   }

   *out_r = (uint8_t)(r * m / 255 * s->tint_r / 255);
   *out_g = (uint8_t)(g * m / 255 * s->tint_g / 255);
   *out_b = (uint8_t)(b * m / 255 * s->tint_b / 255);
}

#endif
