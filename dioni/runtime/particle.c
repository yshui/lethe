#include "particle.h"
#define MAX_PARTICLE 1000
static struct particle p[MAX_PARTICLE];
static struct particle *freep[MAX_PARTICLE];
static int nparticle, fparticle;
struct particle *alloc_particle(void) {
	if (fparticle)
		return freep[--fparticle];
	return &p[nparticle++];
}
void free_particle(struct particle *p) {
	freep[fparticle++] = p;
}
int particle_get_id(struct particle *ip) {
	return ip-&p[0];
}
