include(UseD)
add_d_conditions(VERSION Have_derelict_gl3 Have_derelict_util ${D_CONDITIONS})
include_directories(derelict-gl3/source/)
include_directories(derelict-util/source/)
add_library(derelict-gl3
    derelict-gl3/source/derelict/opengl3/arb.d
    derelict-gl3/source/derelict/opengl3/cgl.d
    derelict-gl3/source/derelict/opengl3/constants.d
    derelict-gl3/source/derelict/opengl3/deprecatedConstants.d
    derelict-gl3/source/derelict/opengl3/deprecatedFunctions.d
    derelict-gl3/source/derelict/opengl3/ext.d
    derelict-gl3/source/derelict/opengl3/functions.d
    derelict-gl3/source/derelict/opengl3/gl.d
    derelict-gl3/source/derelict/opengl3/gl3.d
    derelict-gl3/source/derelict/opengl3/glx.d
    derelict-gl3/source/derelict/opengl3/glxext.d
    derelict-gl3/source/derelict/opengl3/internal.d
    derelict-gl3/source/derelict/opengl3/types.d
    derelict-gl3/source/derelict/opengl3/wgl.d
    derelict-gl3/source/derelict/opengl3/wglext.d
)
target_link_libraries(derelict-gl3 derelict-util dl)
set_target_properties(derelict-gl3 PROPERTIES TEXT_INCLUDE_DIRECTORIES "")
