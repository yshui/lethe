include(UseD)
add_d_conditions(VERSION Have_dioni Have_dioni_sdpc Have_tested ${D_CONDITIONS})
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/source)
add_library(sdpc
    source/sdpc/combinators/combinators.d
    source/sdpc/combinators/package.d
    source/sdpc/package.d
    source/sdpc/parsers.d
    source/sdpc/primitives.d
)
