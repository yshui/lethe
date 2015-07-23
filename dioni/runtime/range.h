#pragma once
#include <stdbool.h>
#include <vec.h>
struct range2 {
	struct vec2 a, o;
};
struct rangei {
	int a, o;
};
struct rangef {
	float a, o;
};
static inline bool vector_in_range2(struct vec2 x, struct range2 r) {
	if (x.x < r.a.x || x.y < r.a.y)
		return false;
	if (x.x >= r.o.x || x.y >= r.o.y)
		return false;
	return true;
}
static inline bool number_in_rangei(int n, struct rangei r) {
	return n >= r.a && n < r.o;
}
static inline bool number_in_rangef(float n, struct rangef r) {
	return n >= r.a && n < r.o;
}
