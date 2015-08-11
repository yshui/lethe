include(UseD)
add_d_conditions(VERSION Have_pack_d ${D_CONDITIONS} )
include_directories(pack/source/)
add_library(pack-d
    pack/source/binary/common.d
    pack/source/binary/format.d
    pack/source/binary/pack.d
    pack/source/binary/package.d
    pack/source/binary/reader.d
    pack/source/binary/unpack.d
    pack/source/binary/writer.d
)
