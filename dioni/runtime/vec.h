#pragma once
struct vec2 {
	double x, y;
};

static inline struct vec2
vec2_mul(struct vec2 a, struct vec2 b) {
	return (struct vec2) {a.x+b.x, a.y+b.y};
}
