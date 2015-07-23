#include <stdlib.h>
#include <actor.h>

struct list_head active_actors = LIST_HEAD_INIT(active_actors);

objpool_def(struct actor, 20, actor, q)

