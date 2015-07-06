#pragma once
#include "../defs.h"
#include "list.h"

#define NOT_HANDLED (-1)

struct event {
	int type;
	union event_variants e;
	struct list_node q;
};

