#include <stdlib.h>
#include <range.h>
#include <vec.h>
static inline float rand_float(struct rangef rng) {
	float x = (float)random()/(float)RAND_MAX;
	x *= rng.o-rng.a;
	return x+rng.a;
}
static inline float rand_int(struct rangei rng) {
	int x = random()%(rng.o-rng.a);
	return x+rng.a;
}
static inline struct vec2 rand_vec2(struct range2 rng) {
	struct rangef x = {rng.a.x, rng.o.x},
		      y = {rng.a.y, rng.o.y};
	return (struct vec2){rand_float(x), rand_float(y)};
}
