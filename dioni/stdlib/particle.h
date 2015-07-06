#pragma once
#include "../defs.h"
struct particle {
	//Type of this particle.
	//Type id is generated by the compiler, with one id per
	//type of particle.
	int type;

	//Two versions of the particle data,
	//each points to a "struct <particle_name>"
	union particle_variants data[2];

	//Current version of this partcile
	int current;
};
struct raw_particle {
	int t;
	void *p;
};
