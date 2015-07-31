include(UseD)
add_d_conditions(VERSION Have_lethe Have_gfm_math Have_gfm_logger Have_logger Have_colorize Have_derelict_util Have_derelict_sdl2 Have_gfm_sdl2 Have_derelict_gl3 ${D_CONDITIONS})
include_directories(${CMAKE_SOURCE_DIR})
include_directories(${CMAKE_CURRENT_SOURCE_DIR})
include_directories(${CMAKE_SOURCE_DIR}/colorize/source)
include_directories(${CMAKE_SOURCE_DIR}/derelict-util/source/)
include_directories(${CMAKE_SOURCE_DIR}/derelict-sdl2/source/)
include_directories(${CMAKE_SOURCE_DIR}/derelict-gl3/source/)
add_library(lethe
    collision/collision.d
    collision/hitbox.d
    collision/package.d
    collision/spatial_hash.d
    dioni/d_interface.d
    dioni/package.d
    engine/buffer.d
    engine/engine.d
    engine/opengl.d
    engine/package.d
    engine/program.d
    engine/shader.d
    engine/texture.d
    engine/uniform.d
    engine/vertex.d
    main.d
)
target_link_libraries(lethe colorize derelict-gl3 derelict-sdl2 derelict-util gfm_logger gfm_math gfm_sdl2 logger script dl)
set_target_properties(lethe PROPERTIES TEXT_INCLUDE_DIRECTORIES "${CMAKE_SOURCE_DIR}/source/shader")
