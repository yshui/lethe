module collision.hitbox;
import gfm.math;
import std.math;
import dioni.opaque;
private pure nothrow @nogc
bool collide_triangle_circle(in ref Circle c, in ref Triangle t) {
	if (t.contain(c.center))
		return true;
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
	pure nothrow @nogc bool collide(in ref LineSeg other) {
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
private nothrow pure @nogc
void vec2min(alias cmp)(ref vec2f res, vec2f c) {
	import std.functional;
	alias le = binaryFun!cmp;
	if (le(c.x, res.x))
		res.x = c.x;
	if (le(c.y, res.y))
		res.y = c.y;
}
struct Triangle {
	vec2f[3] point;
	pure nothrow @nogc bool contain(in ref vec2f p) const {
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
	pure nothrow @nogc bool collide(T)(in ref T other) const {
		static if (is(T == Triangle)) {
			LineSeg ls = {
				start: point[0],
				vec: point[1]-point[0],
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
			return collide_triangle_circle(other, this);
		} else static if (is(T == LineSeg)) {
			if (contain(other.start))
				//Make sure at least on point is outside
				return true;
			foreach(i; 0..3) {
				LineSeg ls = {
					start: point[i],
					vec: point[(i+1)%3]-point[i],
				};
				if (ls.collide(other))
					return true;
			}
			return false;
		} else
			static assert(0);
	}
	pure nothrow @nogc @property box2f aabb() const {
		vec2f min, max;
		min = point[0];
		max = point[0];
		foreach(i; 1..3) {
			vec2min!"a < b"(min, point[i]);
			vec2min!"a > b"(max, point[i]);
		}
		auto ret = box2f(min, max);
		if (ret.empty())
			return box2f(min, max+vec2f(0.1, 0.1));
		return ret;
	}
}
struct Circle {
	float r;
	vec2f center;
	pure nothrow @nogc
	bool collide(T)(in ref T other) const {
		static if (is(T == Circle)) {
			import std.stdio;
			float d = center.distanceTo(other.center);
			return d <= r+other.r;
		} else static if (is(T == Triangle)) {
			return collide_triangle_circle(this, other);
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
	pure nothrow @nogc bool contain(vec2f point) const {
		return center.distanceTo(point) <= r;
	}
	pure nothrow @nogc @property box2f aabb() const {
		auto x = vec2f(r, r);
		return box2f(center-x, center+x);
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
	pure nothrow string str() const {
		final switch(_t) {
		case Type.Circle:
			return "ball";
		case Type.Triangle:
			return "triangle";
		}
	}
	private pure nothrow @nogc from_ball(vec2f c, float r) {
		_t = Type.Circle;
		_c.c.center = c;
		_c.c.r = r;
	}
	private pure nothrow @nogc from_triangle(vec2f[] p) {
		_t = Type.Triangle;
		_c.t.point[0] = p[0];
		_c.t.point[1] = p[1];
		_c.t.point[2] = p[2];
	}
	pure nothrow @nogc this(dioniHitbox* hb) {
		final switch(hb.type) {
		case dioniHitboxType.Ball:
			from_ball(hb.hb.b.center, hb.hb.b.r);
			break;
		case dioniHitboxType.Triangle:
			from_triangle(hb.hb.tri.point);
			break;
		}
	}
	pure nothrow @nogc
	bool collide(T)(in ref T other) const {
		static if (is(T == Circle) || is(T == Triangle)) {
			final switch (_t) {
				case Type.Circle:
					return _c.c.collide(other);
				case Type.Triangle:
					return _c.t.collide(other);
			}
		} else {
			static assert(is(T == Hitbox));
			final switch(other._t) {
				case Type.Circle:
					return collide(other._c.c);
				case Type.Triangle:
					return collide(other._c.t);
			}
		}
	}
	pure nothrow @nogc @property const box2f aabb() {
		final switch (_t) {
			case Type.Circle:
				return _c.c.aabb();
			case Type.Triangle:
				return _c.t.aabb();
		}
		assert(0);
	}
}
