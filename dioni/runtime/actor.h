#pragma once

#include <list.h>
#include <particle.h>
#include <objpool.h>

enum actor_state {
	ACTOR_NEW,
	ACTOR_RUNNING,
	ACTOR_PAUSED
};

struct actor {
	struct particle *owner;
	enum actor_state astate;
	int state;
	struct list_node q;
	struct list_node silblings;
};

extern struct list_head active_actors;
extern struct list_head changed_actors;

objpool_proto(struct actor, actor)

static inline void activate_actor(struct actor *a) {
	assert(list_node_invalid(&a->q));
	assert(list_node_invalid(&a->silblings));
	assert(a->astate != ACTOR_RUNNING);
	list_add(&active_actors, &a->q);
	list_add(&a->owner->actors, &a->silblings);
	a->astate = ACTOR_RUNNING;
}

static inline void create_actor(int id, int state) {
	struct actor *na = alloc_actor();
	na->owner = get_particle_by_id(id);
	na->state = state;
	na->astate = ACTOR_NEW;
	list_node_init(&na->q);
	activate_actor(na);
}
