#include <particle.h>
#include <list.h>
#include <objpool.h>

struct list_head all_particles = LIST_HEAD_INIT(all_particles);
struct list_head changed_particles = LIST_HEAD_INIT(changed_particles);

void init_particle(struct particle *p) {
	list_head_init(&p->hitboxes);
	list_head_init(&p->actors);
	list_node_init(&p->next_changed);
	list_node_init(&p->q);
	p->changed = false;
	list_add(&all_particles, &p->q);
}

objpool_def(struct particle, 1000, particle, q, init_particle)

void mark_particle_as_changed(struct particle *p) {
	if (p->changed)
		return;
	p->changed = true;
	list_add(&changed_particles, &p->next_changed);
}
struct particle *next_particle(struct particle *p) {
	if (p->q.next == (void *)&all_particles)
		return NULL;
	return list_entry(p->q.next, struct particle, q);
}
struct particle *first_particle(void) {
	return list_entry(all_particles.n.next, struct particle, q);
}
