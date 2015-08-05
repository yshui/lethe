include(UseD)
add_d_conditions(VERSION Have_dioni Have_dioni_sdpc Have_tested ${D_CONDITIONS})
include_directories(${CMAKE_CURRENT_SOURCE_DIR})
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../sdpc/source/)
include_directories(${CMAKE_SOURCE_DIR}/tested/source/)
include_directories(${CMAKE_SOURCE_DIR}/docopt.d/source/)
add_executable(dioni
    ast/aggregator.d
    ast/decl/decl.d
    ast/decl/package.d
    ast/decl/particle.d
    ast/expr.d
    ast/match.d
    ast/stmt.d
    ast/symbols.d
    ast/type.d
    ast/builtin.d
    main.d
    parser/atom.d
    parser/decl/decl.d
    parser/decl/event.d
    parser/decl/package.d
    parser/decl/particle.d
    parser/decl/state.d
    parser/decl/tag.d
    parser/decl/vertex.d
    parser/expr.d
    parser/match.d
    parser/package.d
    parser/stmt.d
    parser/utils.d
    utils.d
    mustache.d
    error.d
)
target_link_libraries(dioni sdpc)
set_target_properties(dioni PROPERTIES TEXT_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/../template")
