#include <stdlib.h>
#include <event.h>
#define EVENT_POOL_SIZE 100
struct list_head event_queue = LIST_HEAD_INIT(event_queue);

void init_event(struct event *e) {
	list_node_init(&e->q);
}

objpool_def(struct event, 100, event, q, init_event)


void queue_event(struct event *e) {
	assert(e->q.next == e->q.prev && e->q.next == NULL);
	list_add_tail(&event_queue, &e->q);
}

void event_fence(void) {
	struct event *e = alloc_event();
	e->tgtt = FENCE;
	list_add_tail(&event_queue, &e->q);
}
