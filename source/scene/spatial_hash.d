struct HitboxPair {
	BaseParticle p;
	Hitbox hb;
	(ref HitboxPair)[] next;
	box2i aabb;
};

class SpatialRange(int nhb, int w, int h) {
	private {
		box2i[nhb] aabb;
		Hitbox[] hitbox;
		ulong nowi;
		vec2i now;
		ref const(HitboxPair) head;
		const(SpatialHash!(w, h)) sh;
		bool[HitboxPair*] _poped;
	}
	pure nothrow @nogc empty() {
		return head != null;
	}
	pure nothrow @nogc ref const(HitboxPair)
	front() {
		return head;
	}
	pure nothrow @nogc void _popFront() {
		assert(head.aabb.contain(now));
		vec2i vindex = now-head.aabb.min;
		size_t index = vindex.x*head.aabb.width+vindex.y;
		head = head.next[index];
		if (head == null) {
			now.y++;
			if (now.y >= aabb.max.y) {
				now.y = aabb.min.y;
				now.x++;
			}
			if (aabb.contain(now))
				head = sh.get(now);
			else {
				while (nowi < aabb.length && aabb[nowi].empty())
					nowi++;
				if (nowi < aabb.length) {
					now = aabb[nowi].min;
					head = sh.get(now);
				}
			}
		}
	}
	pure nothrow void popFront() {
		while(nowi < aabb.length) {
			_popFront();
			if (head is null)
				continue;
			if ((&head in _poped) !is null)
				continue;
			_poped[&head] = true;
			if (!head.hb.collide(hitbox[nowi]))
				continue;
		}
	}
	this(const(SpatialHash!(w, h)) ish, const(Hitbox)[] hb) {
		ulong i;
		foreach(x; hb) {
			aabb[i] = ish.intersection(normalize_aabb(x.aabb()));
			i++;
		}

		sh = ish;
		nowi = 0;
		now = aabb[nowi].min;
		head = sh.get(now);
		hitbox = hb;
	}
}

private box2i normalize_aabb(ref const(box2f) aabb, ref const(vec2f) stepv) {
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
		ref HitboxPair[w][h] grid;
		int hbcnt;
		vec2f stepv;
	}
	immutable box2i whole = box2i(vec2i(0, 0), vec2i(w, h));
	@nogc nothrow pure ref HitboxPair get(vec2i pos) {
		assert(whole.contains(pos));
		return grid[pos.x][pos.y];
	}
	@nogc nothrow void reinitialize() {
		foreach(i; 0..w)
			foreach(j; 0..h)
				grid[i][j] = null;
		hbcnt = 0;
	}
	this(int W, int H) {
		step.x = cast(float)W/cast(float)w;
		step.y = cast(float)H/cast(float)h;
		hbcnt = 0;
		hbp.length = 1;
	}
	@nogc nothrow void insert_hitbox(ref const(Hitbox) hb, BaseParticle p) {
		if (hbcnt >= hbp.length)
			hbp.length *= 2;

		ref HitboxPair x = hbp[hbcnt++];
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
	pure nothrow SpatialRange query(const(Hitbox)[] hb) {
		return new SpatialRange!(hb.length)(this, qaabb);
	}
}
