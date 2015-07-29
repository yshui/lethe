#pragma once
#include <stdbool.h>
#include <math.h>
struct vec2 {
	float x, y;
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
vec2_mul1n(float b, struct vec2 a) {
	return vec2_muln1(a, b);
}

static inline struct vec2
vec2_add(struct vec2 a, struct vec2 b) {
	return (struct vec2) {a.x+b.x, a.y+b.y};
}

static inline struct vec2
vec2_sub(struct vec2 a, struct vec2 b) {
	return (struct vec2) {a.x-b.x, a.y-b.y};
}

static inline float
vec2_dotsqrt(struct vec2 a, struct vec2 b) {
	return sqrt(a.x*b.x+a.y*b.y);
}

static inline float
vec2_dot(struct vec2 a, struct vec2 b) {
	return (a.x*b.x+a.y*b.y);
}

static inline struct vec2
vec2_div1(struct vec2 a, float b) {
	return (struct vec2) {a.x*b, a.y*b};
}

