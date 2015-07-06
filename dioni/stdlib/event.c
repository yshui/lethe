#include <stdlib.h>
#include "event.h"
#define EVENT_POOL_SIZE 100
static struct event *event_pool = NULL;
static int water_mark = 0;
static struct list_head eventf = LIST_HEAD_INIT(eventf);
static struct list_head tag_event_queue[MAX_TAG_ID];
static struct list_head particle_type_event_queue[MAX_PARTICLE_ID];

struct event *alloc_event(void) {
	if (!list_empty(&eventf)) {
		struct event *e = list_top(&eventf, struct event, q);
		list_del(&e->q);
		return e;
	}
	if (water_mark >= EVENT_POOL_SIZE) {
		event_pool = malloc(sizeof(struct event)*EVENT_POOL_SIZE);
		water_mark = 0;
	}
	return &event_pool[water_mark++];
}

void free_event(struct event *e) {
	assert(e->q.next == e->q.prev && e->q.next == NULL);
	list_add(&eventf, &e->q);
}

void queue_event_tag(int tag, struct event *e) {
	assert(e->q.next == e->q.prev && e->q.next == NULL);
	list_add(&tag_event_queue[tag], &e->q);
}

void queue_event_particle(int particle, struct event *e) {
	assert(e->q.next == e->q.prev && e->q.next == NULL);
	list_add(&particle_type_event_queue[particle], &e->q);
}
