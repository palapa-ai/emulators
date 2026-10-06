add_library(test_core SHARED test_core.c)
target_include_directories(test_core PRIVATE "${HOST_DIR}/include")
target_compile_features(test_core PRIVATE c_std_11)

add_executable(host_test host_test.c)
target_compile_features(host_test PRIVATE c_std_11)
target_compile_definitions(host_test PRIVATE EMU_HOST_IMPORT _CRT_SECURE_NO_WARNINGS)
target_link_libraries(host_test PRIVATE emulators)
add_custom_command(TARGET host_test POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different "$<TARGET_FILE:emulators>" "$<TARGET_FILE_DIR:host_test>"
)
add_test(NAME windows_emulator_host COMMAND host_test "$<TARGET_FILE:test_core>")
