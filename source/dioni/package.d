module dioni;
public import dioni.d_interface;

struct dioniParticle;

extern(C) {
	dioniParticle *dioni_get_particle_by_id(int);
}
