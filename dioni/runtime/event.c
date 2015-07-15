#include <stdlib.h>
#include "event.h"
#define EVENT_POOL_SIZE 100
struct list_head event_queue;

objpool_def(struct event, 100, event, q)

void queue_event(struct event *e) {
	assert(e->q.next == e->q.prev && e->q.next == NULL);
	list_add(&event_queue, &e->q);
}
