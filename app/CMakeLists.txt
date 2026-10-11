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
    src/browser_window.h
    src/browser_window.mm
    src/command_palette.h
    src/command_palette.mm
    src/devtools_client.h
    src/devtools_client.mm
    src/explorer_app.cc
    src/explorer_app.h
    src/main_mac.mm
    src/pane.h
    src/pane.mm
    src/popout/popout_controller.h
    src/popout/popout_controller.mm
    src/popout/popout_scripts.h
    src/popout/popout_scripts.mm
    src/tab.h
    src/tab_bar.h
    src/tab_bar.mm
    src/top_bar.h
    src/top_bar.mm
    src/ui/ui_resources.mm
    src/ui/ui_scheme.cc
    src/ui/ui_scheme.h
    src/ui/ui_view.h
    src/ui/ui_view.mm
  HELPER_SOURCES
    src/process_helper_mac.cc
    src/renderer_app.cc
    src/renderer_app.h
    src/ui/ui_scheme.cc
    src/ui/ui_scheme.h
  INCLUDE_DIRS
    src
)

# The pop-out's page-side scripts (packages/popout).
add_cef_mac_resources(openp41ge_explorer
  DIR "${CMAKE_SOURCE_DIR}/packages/popout/src"
  DEST popout
  FILES
    core.js
    hold-autoplay.js
)

# The browser's own UI, served at openp41ge://ui/ (src/ui/ui_scheme.h).
add_cef_mac_resources(openp41ge_explorer
  DIR "${CMAKE_CURRENT_SOURCE_DIR}/ui"
  DEST ui
  FILES
    channel.js
    palette.css
    palette.html
    palette.js
    tabbar.css
    tabbar.html
    tabbar.js
    theme.css
    topbar.css
    topbar.html
    topbar.js
)
