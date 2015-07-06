#pragma once

#include "list.h"

struct statemachine {
	struct particle *owner;
	int state;
	struct list_node q;
};
