# The browser app bundle. See cmake/cef_mac_app.cmake.

if(NOT OS_MAC)
  message(FATAL_ERROR "Only macOS is supported so far.")
endif()

set(EXPLORER_VERSION "${PROJECT_VERSION}" CACHE STRING "App version (set from the release tag in CI)")
set(EXPLORER_BUILD_NUMBER "" CACHE STRING
    "CFBundleVersion: a number that goes up with every release (set by the release workflow); default the version")
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
# Updates (Sparkle), for release builds: checked for at the feed, each
# signed with the key whose public half is here (PLAN.md, "GitHub, CI and
# releases"). Development builds never update themselves.
set(EXPLORER_UPDATE_FEED "https://github.com/openp41ge/browser/releases/latest/download/appcast.xml" CACHE STRING
    "Sparkle appcast URL")
set(EXPLORER_UPDATE_KEY "oO3C96DT1nDo0QrN+F6Woe0uxIcsbS1m/LiKOACuTNo=" CACHE STRING
    "Sparkle EdDSA public key (base64); empty: no updater")
set(EXPLORER_PLIST_EXTRA "")
set(EXPLORER_FRAMEWORKS "")
set(EXPLORER_UPDATES OFF)
if(EXPLORER_CHANNEL STREQUAL "release" AND EXPLORER_UPDATE_KEY)
  set(EXPLORER_UPDATES ON)
  set(EXPLORER_SPARKLE "${CMAKE_SOURCE_DIR}/third_party/sparkle/Sparkle.framework")
  if(NOT EXISTS "${EXPLORER_SPARKLE}")
    message(FATAL_ERROR "Sparkle not found at ${EXPLORER_SPARKLE}. Run scripts/fetch-sparkle first.")
  endif()
  set(EXPLORER_FRAMEWORKS "${EXPLORER_SPARKLE}")
  # Checks daily without asking first, and installs what it finds when the
  # app quits (people can turn that off in the update window).
  string(CONCAT EXPLORER_PLIST_EXTRA
    "\t<key>SUFeedURL</key>\n\t<string>${EXPLORER_UPDATE_FEED}</string>\n"
    "\t<key>SUPublicEDKey</key>\n\t<string>${EXPLORER_UPDATE_KEY}</string>\n"
    "\t<key>SUEnableAutomaticChecks</key>\n\t<true/>\n"
    "\t<key>SUAutomaticallyUpdate</key>\n\t<true/>\n"
    "\t<key>SUVerifyUpdateBeforeExtraction</key>\n\t<true/>\n")
elseif(EXPLORER_CHANNEL STREQUAL "release")
  message(WARNING "No EXPLORER_UPDATE_KEY: this release build won't update itself.")
endif()

set(EXPLORER_SIGN_IDENTITY "" CACHE STRING
    "codesign identity for local builds (e.g. \"Apple Development\"), so macOS keeps the app's Keychain access across builds")

add_cef_mac_app(openp41ge_explorer
  PRODUCT_NAME "openp41ge explorer"
  DISPLAY_NAME "${EXPLORER_DISPLAY_NAME}"
  BUNDLE_ID "com.openp41ge.explorer"
  VERSION "${EXPLORER_VERSION}"
  BUILD_NUMBER "${EXPLORER_BUILD_NUMBER}"
  FRAMEWORKS ${EXPLORER_FRAMEWORKS}
  PLIST_EXTRA "${EXPLORER_PLIST_EXTRA}"
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
    src/find_bar.h
    src/find_bar.mm
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
    src/updater.h
    src/updater.mm
    src/ui/site_icon.cc
    src/ui/site_icon.h
    src/ui/ui_live_reload.h
    src/ui/ui_live_reload.mm
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
    "-framework CoreServices"
    "-framework QuartzCore"
  INCLUDE_DIRS
    src
)

if(EXPLORER_CHANNEL STREQUAL "dev")
  # Its UI straight from this checkout, reloaded as it's edited
  # (src/ui/ui_live_reload.h).
  target_compile_definitions(openp41ge_explorer PRIVATE
    EXPLORER_DEV_BUILD=1
    EXPLORER_UI_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/ui")
endif()
if(EXPLORER_UPDATES)
  target_compile_definitions(openp41ge_explorer PRIVATE EXPLORER_UPDATES=1)
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
    findbar.css
    findbar.html
    findbar.js
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
