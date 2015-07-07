#include <stdlib.h>
#include "statemachine.h"
#include "objpool.h"

static struct list_head active_actor;

objpool_def(struct actor, 20, actor, q)

void activate_actor(struct actor *a) {
	assert(list_node_invalid(a->q));
	list_add(&active_actor, &a->q);
	a->state = RUNNING;
}
