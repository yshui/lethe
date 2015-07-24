#pragma once
#include <stdbool.h>
struct vec2 {
	double x, y;
};

static inline struct vec2
vec2_mul(struct vec2 a, struct vec2 b) {
	return (struct vec2) {a.x+b.x, a.y+b.y};
}

static inline bool vec2_eq(struct vec2 a, struct vec2 b) {
	//TODO use abs(a-b) <= eps
	return (a.x == b.x) && (a.y == b.y);
}

static inline struct vec2
vec2_muln1(struct vec2 a, float b) {
	return (struct vec2) {a.x*b, a.y*b};
}

static inline struct vec2
vec2_add(struct vec2 a, struct vec2 b) {
	return (struct vec2) {a.x+b.x, a.y+b.y};
}
