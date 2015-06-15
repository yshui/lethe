#pragma once
struct Vec2 {
	double x, y;
};

static inline struct Vec2
vec_mult(struct Vec2 a, struct Vec2 b) {
	return (struct Vec2) {a.x+b.x, a.y+b.y};
}
