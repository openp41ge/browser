# The browser app bundle and its CEF helper bundles.
# Adapted from CEF's cefsimple sample (BSD-3-Clause, the CEF Authors).

if(NOT OS_MAC)
  message(FATAL_ERROR "Only macOS is supported so far.")
endif()

set(EXPLORER_PRODUCT_NAME "openp41ge explorer")
set(EXPLORER_BUNDLE_ID "com.openp41ge.explorer")
set(EXPLORER_VERSION "${PROJECT_VERSION}" CACHE STRING "App version (set from the release tag in CI)")

set(EXPLORER_SRCS
  src/explorer_app.cc
  src/explorer_app.h
  src/explorer_handler.cc
  src/explorer_handler.h
  src/main_mac.mm
)
set(EXPLORER_HELPER_SRCS
  src/process_helper_mac.cc
)

set(CEF_TARGET "openp41ge_explorer")
set(CEF_HELPER_TARGET "openp41ge_explorer_Helper")
set(CEF_HELPER_OUTPUT_NAME "${EXPLORER_PRODUCT_NAME} Helper")
SET_CEF_TARGET_OUT_DIR()

list(APPEND CEF_COMPILER_FLAGS -fobjc-arc)

set(CEF_APP "${CEF_TARGET_OUT_DIR}/${EXPLORER_PRODUCT_NAME}.app")

# Variables referenced from mac/Info.plist.in.
set(EXECUTABLE_NAME "${EXPLORER_PRODUCT_NAME}")
set(PRODUCT_NAME "${EXPLORER_PRODUCT_NAME}")
set(BUNDLE_ID "${EXPLORER_BUNDLE_ID}")
set(VERSION_SHORT "${EXPLORER_VERSION}")

# Main app bundle.
add_executable(${CEF_TARGET} MACOSX_BUNDLE ${EXPLORER_SRCS})
SET_EXECUTABLE_TARGET_PROPERTIES(${CEF_TARGET})
add_dependencies(${CEF_TARGET} libcef_dll_wrapper)
target_link_libraries(${CEF_TARGET} libcef_dll_wrapper ${CEF_STANDARD_LIBS})
set_target_properties(${CEF_TARGET} PROPERTIES
  OUTPUT_NAME "${EXPLORER_PRODUCT_NAME}"
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/mac/Info.plist.in"
)

# Copy the CEF framework into the bundle's Frameworks directory.
COPY_MAC_FRAMEWORK("${CEF_TARGET}" "${CEF_BINARY_DIR}" "${CEF_APP}")

# CEF needs one helper app per process type (renderer, GPU, ...), named
# "<app name> Helper (<type>)" and placed in the bundle's Frameworks directory.
foreach(_suffix_list ${CEF_HELPER_APP_SUFFIXES})
  string(REPLACE ":" ";" _suffix_list ${_suffix_list})
  list(GET _suffix_list 0 _name_suffix)
  list(GET _suffix_list 1 _target_suffix)
  list(GET _suffix_list 2 _plist_suffix)

  set(_helper_target "${CEF_HELPER_TARGET}${_target_suffix}")
  set(_helper_output_name "${CEF_HELPER_OUTPUT_NAME}${_name_suffix}")

  # Per-helper Info.plist, written by hand because configure_file would use
  # the same variables for every helper.
  set(_helper_info_plist "${CMAKE_CURRENT_BINARY_DIR}/helper-Info${_target_suffix}.plist")
  file(READ "${CMAKE_CURRENT_SOURCE_DIR}/mac/helper-Info.plist.in" _plist_contents)
  string(REPLACE "\${EXECUTABLE_NAME}" "${_helper_output_name}" _plist_contents ${_plist_contents})
  string(REPLACE "\${PRODUCT_NAME}" "${_helper_output_name}" _plist_contents ${_plist_contents})
  string(REPLACE "\${BUNDLE_ID}" "${EXPLORER_BUNDLE_ID}" _plist_contents ${_plist_contents})
  string(REPLACE "\${BUNDLE_ID_SUFFIX}" "${_plist_suffix}" _plist_contents ${_plist_contents})
  string(REPLACE "\${VERSION_SHORT}" "${EXPLORER_VERSION}" _plist_contents ${_plist_contents})
  file(WRITE ${_helper_info_plist} ${_plist_contents})

  add_executable(${_helper_target} MACOSX_BUNDLE ${EXPLORER_HELPER_SRCS})
  SET_EXECUTABLE_TARGET_PROPERTIES(${_helper_target})
  add_dependencies(${_helper_target} libcef_dll_wrapper)
  target_link_libraries(${_helper_target} libcef_dll_wrapper ${CEF_STANDARD_LIBS})
  set_target_properties(${_helper_target} PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST ${_helper_info_plist}
    OUTPUT_NAME ${_helper_output_name}
  )

  add_dependencies(${CEF_TARGET} "${_helper_target}")
  add_custom_command(
    TARGET ${CEF_TARGET}
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CEF_TARGET_OUT_DIR}/${_helper_output_name}.app"
            "${CEF_APP}/Contents/Frameworks/${_helper_output_name}.app"
    VERBATIM
  )
endforeach()
