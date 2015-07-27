#pragma once
#include <vec.h>
#include <list.h>
#include <objpool.h>
struct triangle {
	struct vec2 point[3];
};
struct ball {
	float r;
	struct vec2 center;
};

struct hitbox {
	union {
		struct triangle tr;
		struct ball b;
	};
	struct list_node next;
	struct list_node q;
};

objpool_proto(struct hitbox, hitbox)
