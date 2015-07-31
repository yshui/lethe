cmake_minimum_required(VERSION 3.0)
project(lethe D)

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
	set(D_CONDITIONS DEBUG)
endif()

add_subdirectory(gfm)
add_subdirectory(source)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

include(colorize)
include(derelict-util)
include(derelict-sdl2)
include(derelict-gl3)
