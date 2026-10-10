# openp41ge explorer: a web browser built on CEF binary distributions.
#
#   scripts/fetch-cef
#   cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
#   cmake --build build
cmake_minimum_required(VERSION 3.21)

project(openp41ge_explorer VERSION 0.1.0)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()
set(CMAKE_CONFIGURATION_TYPES Debug Release CACHE STRING "Supported configurations" FORCE)

set(CEF_PLATFORM "macosarm64" CACHE STRING "CEF binary distribution platform")
set(CEF_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party/cef/${CEF_PLATFORM}")
if(NOT EXISTS "${CEF_ROOT}/cmake/FindCEF.cmake")
  message(FATAL_ERROR "CEF not found at ${CEF_ROOT}. Run scripts/fetch-cef first.")
endif()
list(APPEND CMAKE_MODULE_PATH "${CEF_ROOT}/cmake")
find_package(CEF REQUIRED)

include(cmake/cef_mac_app.cmake)

add_subdirectory(${CEF_LIBCEF_DLL_WRAPPER_PATH} libcef_dll_wrapper)
add_subdirectory(app)

option(EXPLORER_BUILD_SPIKES "Build spikes (spikes/)" OFF)
if(EXPLORER_BUILD_SPIKES)
  add_subdirectory(spikes/dom-popout)
endif()

PRINT_CEF_CONFIG()
