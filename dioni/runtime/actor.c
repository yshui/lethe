#include <stdlib.h>
#include <actor.h>

struct list_head active_actors = LIST_HEAD_INIT(active_actors);

void init_actor(struct actor *a) {
	list_node_init(&a->q);
	list_node_init(&a->siblings);
}

objpool_def(struct actor, 20, actor, q, init_actor)

