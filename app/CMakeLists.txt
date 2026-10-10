# The browser app bundle. See cmake/cef_mac_app.cmake.

if(NOT OS_MAC)
  message(FATAL_ERROR "Only macOS is supported so far.")
endif()

set(EXPLORER_VERSION "${PROJECT_VERSION}" CACHE STRING "App version (set from the release tag in CI)")

add_cef_mac_app(openp41ge_explorer
  PRODUCT_NAME "openp41ge explorer"
  BUNDLE_ID "com.openp41ge.explorer"
  VERSION "${EXPLORER_VERSION}"
  SOURCES
    src/explorer_app.cc
    src/explorer_app.h
    src/explorer_handler.cc
    src/explorer_handler.h
    src/main_mac.mm
  HELPER_SOURCES
    src/process_helper_mac.cc
)
