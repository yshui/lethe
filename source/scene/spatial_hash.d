module scene.spatial_hash;
import scene.scene;
import gfm.math;
import std.stdio;
struct HitboxPair {
	BaseParticle p;
	Hitbox hb;
	HitboxPair*[] next;
	box2i aabb;
};
import std.conv;
class SpatialRange(int w, int h) {
	private {
		box2i[] aabb;
		const(Hitbox)[] hitbox;
		ulong nowi;
		vec2i now;
		HitboxPair* head;
		SpatialHash!(w, h) sh;
		bool[HitboxPair*] _poped;
	}
	bool empty() {
		return nowi >= aabb.length;
	}
	HitboxPair* front() {
		assert(head !is null, to!string(nowi)~","~to!string(aabb.length));
		return head;
	}
	pure void _popFront() {
		if (head == null) {
			now.y++;
			if (now.y >= aabb[nowi].max.y) {
				now.y = aabb[nowi].min.y;
				now.x++;
			}
			if (aabb[nowi].contains(now))
				head = sh.get(now);
			else {
				do {
					nowi++;
				}while (nowi < aabb.length && aabb[nowi].empty());
				if (nowi < aabb.length) {
					now = aabb[nowi].min;
					head = sh.get(now);
				}
			}
		} else {
			assert(head.aabb.contains(now));
			vec2i vindex = now-head.aabb.min;
			size_t index = vindex.x*head.aabb.height+vindex.y;
			head = head.next[index];
		}
	}
	pure void popFront() {
		while(nowi < aabb.length) {
			_popFront();
			if (head is null)
				continue;
			if ((head in _poped) !is null)
				continue;
			_poped[head] = true;
			if (!head.hb.collide(hitbox[nowi]))
				continue;
		}
	}
	this(SpatialHash!(w, h) ish, const(Hitbox)[] hb) {
		ulong i;
		aabb.length = hb.length;
		foreach(ref x; hb) {
			aabb[i] = ish.whole.intersection(normalize_aabb(x.aabb, ish.stepv));
			i++;
		}

		hitbox = hb;
		sh = ish;
		nowi = 0;
		while(nowi < aabb.length && aabb[nowi].empty())
			nowi++;
		if (nowi < aabb.length) {
			now = aabb[nowi].min;
			head = sh.get(now);
			if (head is null)
				popFront();
		} else
			head = null;
	}
}

private nothrow pure @nogc box2i normalize_aabb(box2f aabb, vec2f stepv) {
	auto min = aabb.min / stepv;
	auto max = aabb.max / stepv;
	return box2i(
	    vec2i(cast(int)min.x, cast(int)min.y),
	    vec2i(cast(int)max.x+1, cast(int)max.y+1)
	);
}
class SpatialHash(int w, int h) {
	private {
		HitboxPair[] hbp;
		box2i[] qaabb;
		HitboxPair*[w][h] grid;
		int hbcnt;
		vec2f stepv;
	}
	immutable enum box2i whole = box2i(vec2i(0, 0), vec2i(w, h));
	pure HitboxPair* get(vec2i pos) {
		assert(whole.contains(pos), to!string(pos));
		return grid[pos.x][pos.y];
	}
	@nogc nothrow void reinitialize() {
		foreach(i; 0..w)
			foreach(j; 0..h)
				grid[i][j] = null;
		hbcnt = 0;
	}
	this(int W, int H) {
		stepv.x = cast(float)W/cast(float)w;
		stepv.y = cast(float)H/cast(float)h;
		hbcnt = 0;
		hbp.length = 1;
	}
	nothrow void insert_hitbox(ref const(Hitbox) hb, BaseParticle p) {
		if (hbcnt >= hbp.length)
			hbp.length *= 2;

		HitboxPair* x = &hbp[hbcnt++];
		x.p = p;
		x.hb = hb;
		auto aabb = hb.aabb();
		x.aabb = whole.intersection(normalize_aabb(aabb, stepv));
		vec2i d = x.aabb.max-x.aabb.min;
		size_t s = d.x*d.y;
		if (s > x.next.length)
			x.next.length = s;

		int mx = x.aabb.min.x, my = x.aabb.min.y;
		foreach(i; mx..x.aabb.max.x)
			foreach(j; my..x.aabb.max.y) {
				size_t index = (i-mx)*d.y+j-my;
				x.next[index] = grid[i][j];
				grid[i][j] = x;
			}
	}
}
