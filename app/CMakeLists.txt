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
    src/browser_manager.h
    src/browser_manager.mm
    src/devtools_client.h
    src/devtools_client.mm
    src/explorer_app.cc
    src/explorer_app.h
    src/main_mac.mm
    src/page_window.h
    src/page_window.mm
    src/popout/popout_controller.h
    src/popout/popout_controller.mm
    src/popout/popout_scripts.h
    src/popout/popout_scripts.mm
  HELPER_SOURCES
    src/process_helper_mac.cc
    src/renderer_app.cc
    src/renderer_app.h
  # The pop-out's page-side scripts (packages/popout).
  RESOURCES_DIR "${CMAKE_SOURCE_DIR}/packages/popout/src"
  RESOURCES_DEST popout
  RESOURCES
    core.js
    hold-autoplay.js
)
target_include_directories(openp41ge_explorer PRIVATE src)
