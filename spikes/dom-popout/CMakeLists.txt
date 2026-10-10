# DOM pop-out spike (see README.md). Built only with -DEXPLORER_BUILD_SPIKES=ON.

add_cef_mac_app(dom_popout_spike
  PRODUCT_NAME "openp41ge dom popout spike"
  BUNDLE_ID "com.openp41ge.explorer.dompopoutspike"
  VERSION "0.0.0"
  SOURCES
    src/main_mac.mm
    src/popout_script.h
    src/spike_client.h
    src/spike_client.mm
  HELPER_SOURCES
    ${CMAKE_SOURCE_DIR}/app/src/process_helper_mac.cc
)
