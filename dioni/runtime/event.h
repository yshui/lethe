#pragma once
#include "../export.h"
#include "list.h"

#define NOT_HANDLED (-1)

extern struct list_head particle_type_event_queue[];
extern struct list_head tag_event_queue[];
extern struct list_head global_event_queue;

struct event {
	int type;
	union event_variants e;
	struct list_node q;
};

