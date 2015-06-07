module scene.scene;
import gfm.math;
import std.math;
import engine;
private pure nothrow @nogc
bool collide_triangle_circle(Circle c, Triangle t) {
	foreach(i; 0..3) {
		LineSeg ls = {
			start: t.point[i],
			vec: t.point[(i+1)%3]-t.point[i],
		};
		if (c.collide(ls))
			return true;
	}
	return false;
}
pure nothrow @nogc float cross(const vec2f a, const vec2f b) {
	return a.x*b.y-a.y*b.x;
}
struct LineSeg {
	vec2f start;
	vec2f vec;
	pure nothrow @nogc bool collide(ref const LineSeg other) {
		auto x = vec.cross(other.vec);
		if (x.abs() < 1e-6)
			return false;
		auto v2 = other.start-start;
		auto t = v2.cross(vec)/x;
		auto u = v2.cross(other.vec)/x;
		if (t < 0 || t > 1)
			return false;
		if (u < 0 || t > 1)
			return false;
		return true;
	}
}
struct Triangle {
	vec2f[3] point;
	pure nothrow @nogc bool contain(ref const vec2f p) {
		bool pos = true, neg = true;
		foreach(i; 0..3) {
			auto edge = point[(i+1)%3]-point[i];
			auto c = point[i]-p;
			auto x = edge.cross(c);
			pos = pos && (x>0);
			neg = neg && (x<0);
		}
		return pos || neg;
	}
	pure nothrow @nogc bool collide(T)(ref const T other) {
		static if (is(T == Triangle)) {
			LineSeg ls = {
				start: point[0];
				vec: point[1]-point[0];
			};
			if (other.collide(ls))
				return true;
			ls.vec = point[2]-point[0];
			if (other.collide(ls))
				return true;
			foreach(i; point)
				if(other.contain(i))
					return true;
			return false;
		} else static if (is(T == Circle)) {
			return collide_triangle_circle(this, other);
		} else static if (is(T == LineSeg)) {
			if (contain(other.start))
				//Make sure at least on point is outside
				return true;
			foreach(i; 0..3) {
				LineSeg ls = {
					start: point[i];
					vec: point[(i+1)%3]-point[i];
				};
				if (ls.collide(other))
					return true;
			}
			return false;
		} else
			static assert(0);
	}
}
struct Circle {
	float r;
	vec2f center;
	pure nothrow @nogc bool collide(T)(T other) {
		static if (is(T == Circle)) {
			float d = center.distanceTo(other.center);
			return d <= r+other.r;
		} else static if (is(T == Triangle)) {
			return collide_triangle_circle(other, this);
		} else static if (is(T == LineSeg)) {
			if (contain(other.start))
				return true;
			if (contain(other.start+other.vec))
				return true;
			auto v1 = center-other.start;
			auto k = v1.dot(other.vec);
			if (k < 0)
				return false;
			auto len = other.vec.dot(other.vec);
			if (k > len)
				return false;
			if (v1.dot(v1)-k*k/len > r*r)
				return false;
			return true;
		} else
			static assert(0);
	}
	pure nothrow @nogc bool contain(vec2f point) {
		return center.distanceTo(point) <= r;
	}
}
struct Hitbox {
	private {
		enum Type {
			Circle,
			Triangle,
		};
		union Con{
			Circle c;
			Triangle t;
		};

		Con _c;
		Type _t;
	}
	this(vec2f c, float r) {
		_t = Type.Circle;
		_c.c.center = c;
		_c.c.r = r;
	}
	this(vec2f A, vec2f B, vec2f C) {
		_t = Type.Triangle;
		_c.t.point[0] = A;
		_c.t.point[1] = B;
		_c.t.point[2] = C;
	}
	pure nothrow @nogc bool collide(T)(T other) {
		switch (_t) {
			case Type.Circle:
				return _c.c.collide(other);
			case Type.Triangle:
				return _c.t.collide(other);
		}
		return false;
	}
}
class Particle(int n, int m) {
	this() {}
	~this() {}
	pure nothrow @nogc @property
	Hitbox hitbox() { Hitbox x = void; return x; }
	@nogc void gen_scene(BaseSceneData!(n, m) sd) {}
	@nogc void update() {}
	@nogc void collide(Particle other) {}
}
class Scene(int max_particles, int n, int m) {
	Particle!(n, m)[max_particles] ps;
	@nogc void update() {
		foreach(p; ps)
			p.update();
	}
	@nogc void gen_scene(BaseSceneData!(n, m) sd) {
		foreach(p; ps)
			p.gen_scene(sd);
	}
}
