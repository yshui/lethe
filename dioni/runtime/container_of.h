#pragma once
#define container_off(containing_type, member)	\
	offsetof(containing_type, member)
#define container_of(member_ptr, containing_type, member)             \
	((containing_type *)                                          \
	((char *)(member_ptr)                                         \
	- container_off(containing_type, member)))
