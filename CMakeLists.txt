cmake_minimum_required(VERSION 3.0)
project(lethe D)

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
	set(D_CONDITIONS DEBUG)
endif()

add_subdirectory(dioni)
#get_property(dioni_binary TARGET dioni PROPERTY LOCATION)
#message(${dioni_binary})
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/script.o
		   COMMAND dioni -r ${CMAKE_SOURCE_DIR}/dioni/runtime -g ${CMAKE_CURRENT_BINARY_DIR}/gen-dioni ${CMAKE_SOURCE_DIR}/scripts/ball.dn -o ${CMAKE_CURRENT_BINARY_DIR}/script.o
		   DEPENDS scripts/ball.dn
)

add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/ddioni.d
		   COMMAND dioni --donly -o${CMAKE_CURRENT_BINARY_DIR}/ddioni.d -D ddioni ${CMAKE_SOURCE_DIR}/scripts/ball.dn
		   DEPENDS scripts/ball.dn
)

add_library(script STATIC script.o)
set_target_properties(script PROPERTIES LINKER_LANGUAGE C)

add_library(ddioni ddioni.d)
set_target_properties(ddioni PROPERTIES INCLUDE_DIRECTORIES ${CMAKE_SOURCE_DIR}/source)

set(DIONI_INCLUDE ${CMAKE_CURRENT_BINARY_DIR})

add_subdirectory(gfm)
add_subdirectory(source)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

include(colorize)
include(derelict-util)
include(derelict-sdl2)
include(derelict-gl3)
