include(UseD)
add_d_conditions(VERSION Have_colorize ${D_CONDITIONS})
include_directories(colorize/source)
add_library(colorize
    colorize/source/colorize/colors.d
    colorize/source/colorize/cwrite.d
    colorize/source/colorize/package.d
    colorize/source/colorize/winterm.d
)
set_target_properties(colorize PROPERTIES TEXT_INCLUDE_DIRECTORIES "")
