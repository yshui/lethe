#pragma once
#include "particle.h"

struct particle *alloc_particle(void);
void free_particle(struct particle *);
int get_particle_id(struct particle *);
