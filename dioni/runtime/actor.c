#include <stdlib.h>
#include "statemachine.h"
#include "objpool.h"

static struct list_head active_actor;

objpool_def(struct actor, 20, actor, q)


