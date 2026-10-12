# add_cef_mac_app(<target>
#   PRODUCT_NAME <name>      app bundle and executable name
#   DISPLAY_NAME <name>      the name macOS shows (Dock, menu bar); default
#                            PRODUCT_NAME
#   BUNDLE_ID <id>           e.g. com.openp41ge.explorer
#   VERSION <version>
#   [ICON_DIR <dir>]         the app's icon: <dir>/Assets.car (macOS 26) and
#                            <dir>/AppIcon.icns (earlier), named AppIcon
#   SOURCES <files...>       main executable sources
#   HELPER_SOURCES <files...> CEF helper process sources
#   [LIBRARIES <libs...>]
#   [INCLUDE_DIRS <dirs...>] for the main executable and the helpers
#   [SIGN_IDENTITY <identity>]) a codesign identity to sign the bundle with
#                            after each build; empty: the linker's ad hoc
#                            signature
#
# Builds a macOS app bundle for CEF: the main executable, the CEF framework,
# and the helper app per process type ("<name> Helper (Renderer)", ...) that
# CEF requires in Contents/Frameworks. Info.plists come from app/mac/*.in.
# Adapted from CEF's cefsimple sample (BSD-3-Clause, the CEF Authors).
function(add_cef_mac_app target)
  cmake_parse_arguments(ARG "" "PRODUCT_NAME;DISPLAY_NAME;BUNDLE_ID;VERSION;SIGN_IDENTITY;ICON_DIR" "SOURCES;HELPER_SOURCES;LIBRARIES;INCLUDE_DIRS" ${ARGN})

  SET_CEF_TARGET_OUT_DIR()
  list(APPEND CEF_COMPILER_FLAGS -fobjc-arc)

  set(app_path "${CEF_TARGET_OUT_DIR}/${ARG_PRODUCT_NAME}.app")
  set(templates "${CMAKE_SOURCE_DIR}/app/mac")

  # Variables substituted into the Info.plist templates.
  set(BUNDLE_ID "${ARG_BUNDLE_ID}")
  set(VERSION_SHORT "${ARG_VERSION}")

  set(EXECUTABLE_NAME "${ARG_PRODUCT_NAME}")
  set(PRODUCT_NAME "${ARG_PRODUCT_NAME}")
  set(DISPLAY_NAME "${ARG_PRODUCT_NAME}")
  if(ARG_DISPLAY_NAME)
    set(DISPLAY_NAME "${ARG_DISPLAY_NAME}")
  endif()
  # CFBundleIconFile and CFBundleIconName: the icon's name in Contents/Resources.
  set(ICON_NAME "")
  if(ARG_ICON_DIR)
    set(ICON_NAME "AppIcon")
  endif()
  set(info_plist "${CMAKE_CURRENT_BINARY_DIR}/${target}-Info.plist")
  configure_file("${templates}/Info.plist.in" "${info_plist}")

  add_executable(${target} MACOSX_BUNDLE ${ARG_SOURCES})
  if(ARG_ICON_DIR)
    foreach(file Assets.car AppIcon.icns)
      set_source_files_properties("${ARG_ICON_DIR}/${file}" PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
      target_sources(${target} PRIVATE "${ARG_ICON_DIR}/${file}")
    endforeach()
  endif()
  target_include_directories(${target} PRIVATE ${ARG_INCLUDE_DIRS})
  SET_EXECUTABLE_TARGET_PROPERTIES(${target})
  add_dependencies(${target} libcef_dll_wrapper)
  target_link_libraries(${target} libcef_dll_wrapper ${CEF_STANDARD_LIBS} ${ARG_LIBRARIES})
  set_target_properties(${target} PROPERTIES
    OUTPUT_NAME "${ARG_PRODUCT_NAME}"
    MACOSX_BUNDLE_INFO_PLIST "${info_plist}"
  )

  # The CEF framework, as a versioned framework. (CEF's COPY_MAC_FRAMEWORK
  # uses `ln -sf`, which on a rebuild puts a second link inside the folder an
  # existing link points to, e.g. Versions/A/A, and breaks code signing.
  # `ln -sfn` replaces the link.) Copied afresh, so nothing stale is left.
  set(framework "${app_path}/Contents/Frameworks/Chromium Embedded Framework.framework")
  add_custom_command(
    TARGET ${target}
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E rm -rf "${framework}"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CEF_BINARY_DIR}/Chromium Embedded Framework.framework"
            "${framework}/Versions/A"
    COMMAND ln -sfn "A" "${framework}/Versions/Current"
    COMMAND ln -sfn "Versions/Current/Chromium Embedded Framework" "${framework}/Chromium Embedded Framework"
    COMMAND ln -sfn "Versions/Current/Libraries" "${framework}/Libraries"
    COMMAND ln -sfn "Versions/Current/Resources" "${framework}/Resources"
    VERBATIM
  )

  foreach(suffix_list ${CEF_HELPER_APP_SUFFIXES})
    string(REPLACE ":" ";" suffix_list ${suffix_list})
    list(GET suffix_list 0 name_suffix)
    list(GET suffix_list 1 target_suffix)
    list(GET suffix_list 2 BUNDLE_ID_SUFFIX)

    set(helper_target "${target}_Helper${target_suffix}")
    set(helper_name "${ARG_PRODUCT_NAME} Helper${name_suffix}")

    set(EXECUTABLE_NAME "${helper_name}")
    set(PRODUCT_NAME "${helper_name}")
    set(helper_plist "${CMAKE_CURRENT_BINARY_DIR}/${helper_target}-Info.plist")
    configure_file("${templates}/helper-Info.plist.in" "${helper_plist}")

    add_executable(${helper_target} MACOSX_BUNDLE ${ARG_HELPER_SOURCES})
    target_include_directories(${helper_target} PRIVATE ${ARG_INCLUDE_DIRS})
    SET_EXECUTABLE_TARGET_PROPERTIES(${helper_target})
    add_dependencies(${helper_target} libcef_dll_wrapper)
    target_link_libraries(${helper_target} libcef_dll_wrapper ${CEF_STANDARD_LIBS})
    set_target_properties(${helper_target} PROPERTIES
      OUTPUT_NAME "${helper_name}"
      MACOSX_BUNDLE_INFO_PLIST "${helper_plist}"
    )

    add_dependencies(${target} "${helper_target}")
    add_custom_command(
      TARGET ${target}
      POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_directory
              "${CEF_TARGET_OUT_DIR}/${helper_name}.app"
              "${app_path}/Contents/Frameworks/${helper_name}.app"
      VERBATIM
    )
  endforeach()

  # Signed with a real identity, every build has the same designated
  # requirement (bundle ID + certificate), so what macOS grants the app
  # (e.g. "Always Allow" for its Keychain item, Chromium Safe Storage)
  # carries over to the next build; an ad hoc signature is new each time.
  # Inside out: the framework and helpers, then the app. A target of its own
  # that runs on every build: a build that only copies resources (no link,
  # so no POST_BUILD) still changes the bundle.
  if(ARG_SIGN_IDENTITY)
    set(sign codesign --force --timestamp=none --sign "${ARG_SIGN_IDENTITY}")
    set(commands COMMAND ${sign} "${app_path}/Contents/Frameworks/Chromium Embedded Framework.framework")
    foreach(suffix_list ${CEF_HELPER_APP_SUFFIXES})
      string(REPLACE ":" ";" suffix_list ${suffix_list})
      list(GET suffix_list 0 name_suffix)
      list(APPEND commands COMMAND ${sign} "${app_path}/Contents/Frameworks/${ARG_PRODUCT_NAME} Helper${name_suffix}.app")
    endforeach()
    add_custom_target(${target}_sign ALL ${commands} COMMAND ${sign} "${app_path}" VERBATIM)
    add_dependencies(${target}_sign ${target})
  endif()
endfunction()

# add_cef_mac_resources(<target> DIR <dir> [DEST <subdir>] FILES <files...>)
#
# Copies files under <dir> into the app bundle's Contents/Resources[/<subdir>],
# keeping their paths relative to <dir>.
function(add_cef_mac_resources target)
  cmake_parse_arguments(ARG "" "DIR;DEST" "FILES" ${ARGN})
  foreach(file ${ARG_FILES})
    set(path "${ARG_DIR}/${file}")
    get_filename_component(subdir "${file}" DIRECTORY)
    set(location "Resources")
    foreach(part ${ARG_DEST} ${subdir})
      set(location "${location}/${part}")
    endforeach()
    set_source_files_properties("${path}" PROPERTIES MACOSX_PACKAGE_LOCATION "${location}")
    target_sources(${target} PRIVATE "${path}")
  endforeach()
endfunction()
