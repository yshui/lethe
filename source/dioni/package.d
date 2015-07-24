module dioni;
public import dioni.d_interface;

struct dioniParticle;

enum dioniEventTarget {
	Particle = 0,
	ParticleType,
	Tag,
	Global,
	Fence
}

struct dioniEvent {
	dioniEventTarget tgtt;
	int target;
	int event_type;
	dioniEventVariant v;
	void*[2] padding;
}

extern(C) {
	dioniParticle *dioni_get_particle_by_id(int);
	int tick_start();
	void queue_event(dioniEvent *e);
	dioniEvent *alloc_event();
}
