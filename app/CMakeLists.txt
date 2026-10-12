# The browser app bundle. See cmake/cef_mac_app.cmake.

if(NOT OS_MAC)
  message(FATAL_ERROR "Only macOS is supported so far.")
endif()

set(EXPLORER_VERSION "${PROJECT_VERSION}" CACHE STRING "App version (set from the release tag in CI)")
# A release build keeps its profile in "openp41ge explorer"; a development
# build in "openp41ge explorer development", so testing never touches the
# profile of the browser in everyday use (or its saved site icons).
set(EXPLORER_CHANNEL "dev" CACHE STRING "dev (local builds) or release (published builds)")
set_property(CACHE EXPLORER_CHANNEL PROPERTY STRINGS dev release)
if(NOT EXPLORER_CHANNEL MATCHES "^(dev|release)$")
  message(FATAL_ERROR "EXPLORER_CHANNEL must be dev or release, not ${EXPLORER_CHANNEL}")
endif()
# The icon (app/mac/release or dev, made from brand/*.svg by
# scripts/make-icons): a development build's has hazard tape and a cone, to
# tell it from a release.
if(EXPLORER_CHANNEL STREQUAL "dev")
  set(EXPLORER_ICON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/mac/dev")
else()
  set(EXPLORER_ICON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/mac/release")
endif()
# What macOS calls a development build in the Dock and the menu bar: the
# engine it runs ("Chromium", as a dev Electron app shows "Electron"). Its
# windows' titles say which app it is (BrowserWindow::UpdateTitle).
if(EXPLORER_CHANNEL STREQUAL "dev")
  set(EXPLORER_DISPLAY_NAME "Chromium")
else()
  set(EXPLORER_DISPLAY_NAME "openp41ge explorer")
endif()
set(EXPLORER_SIGN_IDENTITY "" CACHE STRING
    "codesign identity for local builds (e.g. \"Apple Development\"), so macOS keeps the app's Keychain access across builds")

add_cef_mac_app(openp41ge_explorer
  PRODUCT_NAME "openp41ge explorer"
  DISPLAY_NAME "${EXPLORER_DISPLAY_NAME}"
  BUNDLE_ID "com.openp41ge.explorer"
  VERSION "${EXPLORER_VERSION}"
  SIGN_IDENTITY "${EXPLORER_SIGN_IDENTITY}"
  ICON_DIR "${EXPLORER_ICON_DIR}"
  SOURCES
    src/borderless.h
    src/borderless.mm
    src/browser_manager.h
    src/browser_manager.mm
    src/browser_window.h
    src/browser_window.mm
    src/devtools_client.h
    src/devtools_client.mm
    src/divider_handles.h
    src/divider_handles.mm
    src/drop_preview.h
    src/drop_preview.mm
    src/focus_bar.h
    src/focus_bar.mm
    src/explorer_app.cc
    src/explorer_app.h
    src/grid_scrollbar.h
    src/grid_scrollbar.mm
    src/history.cc
    src/history.h
    src/main_mac.mm
    src/menu_window.h
    src/menu_window.mm
    src/pane.h
    src/pane.mm
    src/popout/popout_controller.h
    src/popout/popout_controller.mm
    src/popout/popout_scripts.h
    src/popout/popout_scripts.mm
    src/tab.h
    src/tab_drag_image.h
    src/tab_drag_image.mm
    src/suggestions_popup.h
    src/suggestions_popup.mm
    src/tab_bar.h
    src/tab_bar.mm
    src/top_bar.h
    src/top_bar.mm
    src/ui/site_icon.cc
    src/ui/site_icon.h
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
  LIBRARIES
    "-framework QuartzCore"
  INCLUDE_DIRS
    src
)

if(EXPLORER_CHANNEL STREQUAL "dev")
  target_compile_definitions(openp41ge_explorer PRIVATE EXPLORER_DEV_BUILD=1)
endif()

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
    menu.css
    menu.html
    menu.js
    suggestions.css
    suggestions.html
    suggestions.js
    tabbar.css
    tabbar.html
    tabbar.js
    topbar.css
    topbar.html
    topbar.js
)

# The start page, served at openp41ge://start/.
add_cef_mac_resources(openp41ge_explorer
  DIR "${CMAKE_CURRENT_SOURCE_DIR}/ui/start"
  DEST start
  FILES
    index.html
    private.css
    private.html
    start.css
    start.js
)

# Served to both at shared/.
add_cef_mac_resources(openp41ge_explorer
  DIR "${CMAKE_CURRENT_SOURCE_DIR}/ui/shared"
  DEST shared
  FILES
    address.js
    theme.css
)
