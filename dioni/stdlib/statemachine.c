#include <stdlib.h>
#include "statemachine.h"
#include "objpool.h"

static struct list_head active_machine;

objpool_def(struct statemachine, 20, statemachine, q)


