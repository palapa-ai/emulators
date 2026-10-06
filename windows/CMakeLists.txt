cmake_minimum_required(VERSION 3.14)
project(emulator_palapa LANGUAGES C)

set(HOST_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../macos/emulator_palapa/Sources/emulators_host")
add_library(emulators SHARED
  "${HOST_DIR}/libretro_host.c"
  "gamepad.c"
)
target_include_directories(emulators PUBLIC "${HOST_DIR}/include")
target_include_directories(emulators PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_features(emulators PRIVATE c_std_11)
target_compile_definitions(emulators PRIVATE _CRT_SECURE_NO_WARNINGS WIN32_LEAN_AND_MEAN NOMINMAX)
target_link_libraries(emulators PRIVATE winmm xinput9_1_0)

set(emulator_palapa_bundled_libraries "$<TARGET_FILE:emulators>" PARENT_SCOPE)

option(PALAPA_EMULATOR_TESTS "Build the native host regression tests" OFF)
if(PALAPA_EMULATOR_TESTS)
  enable_testing()
  add_subdirectory(test)
endif()
