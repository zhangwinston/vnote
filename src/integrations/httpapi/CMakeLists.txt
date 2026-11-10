add_library(vnote_httpapi STATIC
  apicredentialstore.cpp apicredentialstore.h
  httpapicontroller.cpp httpapicontroller.h
  vnoteapibackend.cpp vnoteapibackend.h
)

target_compile_features(vnote_httpapi PUBLIC cxx_std_17)
target_include_directories(vnote_httpapi PUBLIC "${PROJECT_SOURCE_DIR}/src")
target_link_libraries(vnote_httpapi
  PUBLIC vnote_api Qt${QT_DEFAULT_MAJOR_VERSION}::Core
  PRIVATE core_services Qt${QT_DEFAULT_MAJOR_VERSION}::Concurrent
)
# QTextCodec: native QtCore on Qt 5, Core5Compat on Qt 6.
if(QT_DEFAULT_MAJOR_VERSION GREATER 5)
  target_link_libraries(vnote_httpapi PRIVATE Qt6::Core5Compat)
endif()
if(WIN32)
  target_link_libraries(vnote_httpapi PRIVATE advapi32)
endif()
set_target_properties(vnote_httpapi PROPERTIES AUTOMOC ON)
