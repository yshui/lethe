#pragma once
#include <vec.h>
#include <list.h>
#include <objpool.h>
#include <particle.h>
struct triangle {
	struct vec2 point[3];
};
struct ball {
	float r;
	struct vec2 center;
};

struct hitbox {
	enum {
		HITBOX_BALL = 0,
		HITBOX_TRIANGLE,
	} type;
	union {
		struct triangle tr;
		struct ball b;
	};
	struct list_node q;
};

objpool_proto(struct hitbox, hitbox)

struct hitbox *harvest_hitboxes(struct particle *);
struct hitbox *next_hitbox(struct hitbox *);
