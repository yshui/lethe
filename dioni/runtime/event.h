#pragma once
#include <export.h>
#include <objpool.h>
#include <list.h>

#define NOT_HANDLED (-1)

extern struct list_head event_queue;

enum target_type {
	PARTICLE = 0,
	PARTICLE_TYPE,
	TAG,
	GLOBAL,
	FENCE
};

struct event {
	enum target_type tgtt;
	int target;
	int event_type;
	union event_variants e;
	struct list_node q;
};

void queue_event(struct event *e);
void event_fence(void);

objpool_proto(struct event, event)
