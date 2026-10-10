# add_cef_mac_app(<target>
#   PRODUCT_NAME <name>      app bundle and executable name
#   BUNDLE_ID <id>           e.g. com.openp41ge.explorer
#   VERSION <version>
#   SOURCES <files...>       main executable sources
#   HELPER_SOURCES <files...> CEF helper process sources
#   [LIBRARIES <libs...>])
#
# Builds a macOS app bundle for CEF: the main executable, the CEF framework,
# and the helper app per process type ("<name> Helper (Renderer)", ...) that
# CEF requires in Contents/Frameworks. Info.plists come from app/mac/*.in.
# Adapted from CEF's cefsimple sample (BSD-3-Clause, the CEF Authors).
function(add_cef_mac_app target)
  cmake_parse_arguments(ARG "" "PRODUCT_NAME;BUNDLE_ID;VERSION" "SOURCES;HELPER_SOURCES;LIBRARIES" ${ARGN})

  SET_CEF_TARGET_OUT_DIR()
  list(APPEND CEF_COMPILER_FLAGS -fobjc-arc)

  set(app_path "${CEF_TARGET_OUT_DIR}/${ARG_PRODUCT_NAME}.app")
  set(templates "${CMAKE_SOURCE_DIR}/app/mac")

  # Variables substituted into the Info.plist templates.
  set(BUNDLE_ID "${ARG_BUNDLE_ID}")
  set(VERSION_SHORT "${ARG_VERSION}")

  set(EXECUTABLE_NAME "${ARG_PRODUCT_NAME}")
  set(PRODUCT_NAME "${ARG_PRODUCT_NAME}")
  set(info_plist "${CMAKE_CURRENT_BINARY_DIR}/${target}-Info.plist")
  configure_file("${templates}/Info.plist.in" "${info_plist}")

  add_executable(${target} MACOSX_BUNDLE ${ARG_SOURCES})
  SET_EXECUTABLE_TARGET_PROPERTIES(${target})
  add_dependencies(${target} libcef_dll_wrapper)
  target_link_libraries(${target} libcef_dll_wrapper ${CEF_STANDARD_LIBS} ${ARG_LIBRARIES})
  set_target_properties(${target} PROPERTIES
    OUTPUT_NAME "${ARG_PRODUCT_NAME}"
    MACOSX_BUNDLE_INFO_PLIST "${info_plist}"
  )

  COPY_MAC_FRAMEWORK("${target}" "${CEF_BINARY_DIR}" "${app_path}")

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
endfunction()
