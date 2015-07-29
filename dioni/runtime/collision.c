#include <collision.h>
#include <objpool.h>

void init_hitbox(struct hitbox *h) {
	list_node_init(&h->q);
}
objpool_def(struct hitbox, 1000, hitbox, q, init_hitbox)

struct hitbox *harvest_hitboxes(struct particle *p) {
	if (list_empty(&p->hitboxes))
		return NULL;

	struct hitbox *h = list_top(&p->hitboxes, struct hitbox, q),
		      *lasth = list_tail(&p->hitboxes, struct hitbox, q);
	lasth->q.next = NULL;

	list_head_init(&p->hitboxes);
	return h;
}

struct hitbox *next_hitbox(struct hitbox *h) {
	struct hitbox *ret = NULL;
	if (h->q.next)
		ret = list_entry(h->q.next, struct hitbox, q);
	list_node_init(&h->q);
	free_hitbox(h);
	return ret;
}
