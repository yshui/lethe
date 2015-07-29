#include <particle.h>
#include <list.h>
#define MAX_PARTICLE 1000
static struct particle p[MAX_PARTICLE];
static struct particle *freep[MAX_PARTICLE];
static int nparticle, fparticle;

struct list_head changed_particles = LIST_HEAD_INIT(changed_particles);
struct particle *alloc_particle(void) {
	if (fparticle)
		return freep[--fparticle];
	return &p[nparticle++];
}
void free_particle(struct particle *p) {
	freep[fparticle++] = p;
}
int get_particle_id(struct particle *ip) {
	return ip-&p[0];
}
struct particle *get_particle_by_id(int id) {
	return p+id;
}
void mark_particle_as_changed(struct particle *p) {
	if (p->changed)
		return;
	p->changed = true;
	list_add(&changed_particles, &p->next_changed);
}
