#pragma once

#include <list.h>

enum actor_state {
	RUNNING,
	PAUSED
};

struct actor {
	struct particle *owner;
	enum actor_state astate;
	int state;
	struct list_node q;
	struct list_node silblings;
	struct list_node next_changed;
};

extern struct list_head active_actors;
extern struct list_head changed_actors;
