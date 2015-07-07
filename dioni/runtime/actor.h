#pragma once

#include "list.h"

enum actor_state {
	RUNNING,
	PAUSED
};

struct actor {
	struct particle *owner;
	enum actor_state astate;
	int state;
	struct list_node q;
};
