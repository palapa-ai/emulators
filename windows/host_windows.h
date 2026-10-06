#ifndef EMULATOR_HOST_WINDOWS_H
#define EMULATOR_HOST_WINDOWS_H

#include <windows.h>
#include <mmsystem.h>

typedef CRITICAL_SECTION emu_mutex;
#define emu_mutex_init InitializeCriticalSection
#define emu_mutex_lock EnterCriticalSection
#define emu_mutex_unlock LeaveCriticalSection
#define emu_mutex_destroy DeleteCriticalSection

static wchar_t *wide_path(const char *path)
{
   int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, NULL, 0);
   if (!length) return NULL;
   wchar_t *wide = calloc((size_t)length, sizeof(wchar_t));
   if (!wide) return NULL;
   if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide, length))
   {
      free(wide);
      return NULL;
   }
   return wide;
}

static void *emu_library_open(const char *path)
{
   wchar_t *wide = wide_path(path);
   if (!wide) return NULL;
   HMODULE library = LoadLibraryExW(wide, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
   DWORD error = GetLastError();
   free(wide);
   SetLastError(error);
   return library;
}

static void *emu_library_symbol(void *library, const char *name)
{
   return (void *)GetProcAddress((HMODULE)library, name);
}

static void emu_library_close(void *library)
{
   FreeLibrary((HMODULE)library);
}

static const char *emu_library_error(void)
{
   static char error[512];
   DWORD code = GetLastError();
   if (!FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
         NULL, code, 0, error, sizeof(error), NULL))
      snprintf(error, sizeof(error), "Cannot load libretro core (Windows error %lu)", code);
   return error;
}

static FILE *emu_rom_open(const char *path)
{
   wchar_t *wide = wide_path(path);
   if (!wide) return NULL;
   FILE *file = _wfopen(wide, L"rb");
   free(wide);
   return file;
}

#endif
