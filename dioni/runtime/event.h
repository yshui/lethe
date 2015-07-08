#pragma once
#include "../export.h"
#include "list.h"

#define NOT_HANDLED (-1)

extern struct list_head event_queue;

enum target_type {
	PARTICLE,
	PARTICLE_TYPE,
	TAG,
	GLOBAL
};

struct event {
	enum target_type tgtt;
	int target;
	int event_type;
	union event_variants e;
	struct list_node q;
};

