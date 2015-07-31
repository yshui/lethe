module collision;
public import collision.collision;
public import collision.hitbox;
import gfm.math;
package nothrow pure @nogc box2i normalize_aabb(box2f aabb, vec2f stepv) {
	auto min = aabb.min / stepv;
	auto max = aabb.max / stepv;
	return box2i(
	    vec2i(cast(int)min.x, cast(int)min.y),
	    vec2i(cast(int)max.x+1, cast(int)max.y+1)
	);
}
class CollisionRange {
	import dioni.opaque;
	bool empty() { return true; }
	dioniParticle* front() { return null; }
	void popFront() { }
}
