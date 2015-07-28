#include <collision.h>
#include <objpool.h>

void init_hitbox(struct hitbox *h) {
	list_node_init(&h->q);
	list_node_init(&h->next);
}
objpool_def(struct hitbox, 1000, hitbox, q, init_hitbox)
