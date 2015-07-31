include(UseD)
add_d_conditions(VERSION Have_derelict_sdl2 Have_derelict_util ${D_CONDITIONS})
include_directories(derelict-sdl2/source/)
include_directories(derelict-util/source/)
add_library(derelict-sdl2
    derelict-sdl2/source/derelict/sdl2/functions.d
    derelict-sdl2/source/derelict/sdl2/image.d
    derelict-sdl2/source/derelict/sdl2/mixer.d
    derelict-sdl2/source/derelict/sdl2/net.d
    derelict-sdl2/source/derelict/sdl2/sdl.d
    derelict-sdl2/source/derelict/sdl2/ttf.d
    derelict-sdl2/source/derelict/sdl2/types.d
)
target_link_libraries(derelict-sdl2 derelict-util dl)
set_target_properties(derelict-sdl2 PROPERTIES TEXT_INCLUDE_DIRECTORIES "")
