cmake_minimum_required(VERSION 3.0)
project(lethe D)

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
	set(D_CONDITIONS DEBUG)
endif()

if (CMAKE_BUILD_TYPE STREQUAL "Release")
	set(D_CONDITIONS RELEASE)
	set(CMAKE_D_FLAGS "-g -O")
	set(DIONI_FLAGS "--release")
endif()

set(DIONI_RUNTIME_SRC
	dioni/runtime/actor.c
	dioni/runtime/actor.h
	dioni/runtime/collision.c
	dioni/runtime/collision.h
	dioni/runtime/container_of.h
	dioni/runtime/event.c
	dioni/runtime/event.h
	dioni/runtime/list.h
	dioni/runtime/mainloop.c
	dioni/runtime/mainloop.h
	dioni/runtime/objpool.h
	dioni/runtime/particle.c
	dioni/runtime/particle.h
	dioni/runtime/rand.h
	dioni/runtime/range.h
	dioni/runtime/render.c
	dioni/runtime/render.h
	dioni/runtime/tag.h
	dioni/runtime/vec.h
)

add_subdirectory(dioni)
#get_property(dioni_binary TARGET dioni PROPERTY LOCATION)
#message(${dioni_binary})
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/script.o
		   COMMAND dioni -r ${CMAKE_SOURCE_DIR}/dioni/runtime -g ${CMAKE_CURRENT_BINARY_DIR}/gen-dioni ${CMAKE_SOURCE_DIR}/scripts/ball.dn -t ${CMAKE_SOURCE_DIR}/texture -o ${CMAKE_CURRENT_BINARY_DIR}/script.o ${DIONI_FLAGS}
		   DEPENDS dioni scripts/ball.dn ${DIONI_RUNTIME_SRC}
)

add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/ddioni.d
		   COMMAND dioni --donly -o${CMAKE_CURRENT_BINARY_DIR}/ddioni.d -D ddioni ${CMAKE_SOURCE_DIR}/scripts/ball.dn
		   DEPENDS dioni scripts/ball.dn
)

add_library(script STATIC script.o)
set_target_properties(script PROPERTIES LINKER_LANGUAGE C)

add_library(ddioni ddioni.d)
set_target_properties(ddioni PROPERTIES INCLUDE_DIRECTORIES "${CMAKE_SOURCE_DIR}/source;${CMAKE_SOURCE_DIR}")

set(DIONI_INCLUDE ${CMAKE_CURRENT_BINARY_DIR})

add_subdirectory(gfm)
add_subdirectory(source)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

include(colorize)
include(derelict-util)
include(derelict-sdl2)
include(derelict-gl3)
include(pack-d)
