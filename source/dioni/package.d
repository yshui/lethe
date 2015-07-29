module dioni;
public import dioni.d_interface;
import gfm.math;

struct dioniParticle;

enum dioniEventTarget {
	Particle = 0,
	ParticleType,
	Tag,
	Global,
	Fence
}

enum dioniHitboxType {
	Ball = 0,
	Triangle
}

struct dioniHitboxTriangle {
	vec2f[3] point;
}

struct dioniHitboxBall {
	float r;
	vec2f center;
}

struct dioniHitbox {
	dioniHitboxType type;

	private union _Hitbox{
		dioniHitboxTriangle tri;
		dioniHitboxBall b;
	};

	_Hitbox hb;
	void *[2] padding;
}

struct dioniEvent {
	dioniEventTarget tgtt;
	size_t target;
	int event_type;
	dioniEventVariant v;
	void*[2] padding;
}

extern(C) {
	int tick_start();
	void queue_event(dioniEvent *e);
	void event_fence();
	dioniEvent* alloc_event();
	void render_queue_bind_buf(int index, void *buf, size_t cap);
	void render_queue_bind_indices(int index, uint *buf, size_t cap);
	int render_queue_get_nvert(int index);
	int render_queue_get_nind(int index);
	dioniHitbox* harvest_hitboxes(dioniParticle*);
	dioniHitbox* next_hitbox(dioniHitbox*);
	dioniParticle* first_particle();
	dioniParticle* next_particle(dioniParticle*);
}
