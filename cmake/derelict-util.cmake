include(UseD)
add_d_conditions(VERSION Have_derelict_util ${D_CONDITIONS})
include_directories(derelict-util/source/)
add_library(derelict-util
    derelict-util/source/derelict/util/exception.d
    derelict-util/source/derelict/util/loader.d
    derelict-util/source/derelict/util/sharedlib.d
    derelict-util/source/derelict/util/system.d
    derelict-util/source/derelict/util/wintypes.d
    derelict-util/source/derelict/util/xtypes.d
)
target_link_libraries(derelict-util  dl)
set_target_properties(derelict-util PROPERTIES TEXT_INCLUDE_DIRECTORIES "")
