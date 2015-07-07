#include <stdlib.h>
#include "event.h"
#include "objpool.h"
#define EVENT_POOL_SIZE 100
struct list_head tag_event_queue[MAX_TAG_ID];
struct list_head particle_type_event_queue[MAX_PARTICLE_ID];

objpool_def(struct event, 100, event, q)

void queue_event_tag(int tag, struct event *e) {
	assert(e->q.next == e->q.prev && e->q.next == NULL);
	list_add(&tag_event_queue[tag], &e->q);
}

void queue_event_particle(int particle, struct event *e) {
	assert(e->q.next == e->q.prev && e->q.next == NULL);
	list_add(&particle_type_event_queue[particle], &e->q);
}

