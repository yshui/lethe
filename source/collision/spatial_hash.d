module collision.spatial_hash;
import collision;
import gfm.math;
import std.stdio;
import std.conv;
private struct HitboxPair {
	int id;
	Hitbox hb;
	HitboxPair*[] next;
	box2f aabb;
	//int generational_number;
}
class SpatialRange(int w, int h) : CollisionRange{
	private {
		box2i aabb;
		box2f aabbf;
		const(Hitbox)[] hitbox;
		ulong nowi;
		vec2i now;
		HitboxPair* head;
		SpatialHash!(w, h) sh;
		bool[HitboxPair*] _checked;
		int self;
		//int generation; //Incremented every new query
	}
	override pure nothrow @nogc bool empty() {
		return nowi >= hitbox.length;
	}
	override pure nothrow @nogc int front() {
		assert(head !is null);
		return head.id;
	}
	pure nothrow @nogc void _popFront() {
		if (head == null) {
			now.y++;
			if (now.y >= aabb.max.y) {
				now.y = aabb.min.y;
				now.x++;
			}
			if (aabb.contains(now))
				head = sh.get(now);
			else {
				nowi++;
				while (nowi < hitbox.length) {
					aabbf = sh.whole.intersection(hitbox[nowi].aabb);
					if (!aabbf.empty())
						break;
					nowi++;
				}
				if (nowi < hitbox.length) {
					aabb = normalize_aabb(aabbf, sh.stepv);
					now = aabb.min;
					head = sh.get(now);
				}
			}
		} else {
			box2i haabbi = normalize_aabb(head.aabb, sh.stepv);
			assert(haabbi.contains(now));
			vec2i vindex = now-haabbi.min;
			size_t index = vindex.x*haabbi.height+vindex.y;
			head = head.next[index];
		}
	}
	private nothrow pure bool qualify() {
		if (head is null)
			return false;
		if (head.id == self)
			return false;
		if (!head.aabb.intersects(aabbf))
			return false;
		if (!head.hb.collide(hitbox[nowi]))
			return false;
		//if (head.generational_number < generation)
		if ((head in _checked) !is null) //hash is slow
			return false;
		_checked[head] = true;
		//head.generation_number = generation
		return true;
	}
	override pure nothrow void popFront() {
		while(nowi < hitbox.length) {
			_popFront();
			if (qualify())
				break;
		}
	}
	this(SpatialHash!(w, h) ish, const(Hitbox)[] hb, int self_id) {
		self = self_id;
		hitbox = hb;
		sh = ish;
		nowi = 0;
		while(nowi < hb.length) {
			aabbf = ish.whole.intersection(hb[nowi].aabb);
			if (!aabbf.empty())
				break;
			nowi++;
		}
		aabb = normalize_aabb(aabbf, ish.stepv);
		if (nowi < hb.length) {
			now = aabb.min;
			head = sh.get(now);
			if (!qualify())
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
	    vec2i(cast(int)(max.x-1e-6)+1, cast(int)(max.y-1e-6)+1)
	);
}
class SpatialHash(int w, int h) {
	private {
		HitboxPair[] hbp;
		box2f whole;
		HitboxPair*[w][h] grid;
		int hbcnt;
		vec2f stepv;
	}
	pure nothrow @nogc HitboxPair* get(vec2i pos) {
		assert(pos.x >= 0 && pos.y >= 0);
		assert(pos.x < w && pos.y < h);
		return grid[pos.x][pos.y];
	}
	pure @nogc nothrow void reinitialize() {
		foreach(i; 0..w)
			foreach(j; 0..h)
				grid[i][j] = null;
		hbcnt = 0;
	}
	this(int W, int H) {
		whole = box2f(vec2f(0, 0), vec2f(W, H));
		stepv.x = cast(float)W/cast(float)w;
		stepv.y = cast(float)H/cast(float)h;
		hbcnt = 0;
		hbp.length = 1;
	}
	pure nothrow void insert_hitbox(ref const(Hitbox) hb, int id) {
		auto aabb = whole.intersection(hb.aabb);
		if (aabb.empty())
			return;

		if (hbcnt >= hbp.length)
			hbp.length *= 2;

		HitboxPair* x = &hbp[hbcnt++];
		x.id = id;
		x.hb = hb;
		x.aabb = aabb;
		auto aabbi = normalize_aabb(aabb, stepv);
		vec2i d = aabbi.max-aabbi.min;
		size_t s = d.x*d.y;
		if (s > x.next.length)
			x.next.length = s;

		int mx = aabbi.min.x, my = aabbi.min.y;
		foreach(i; mx..aabbi.max.x)
			foreach(j; my..aabbi.max.y) {
				size_t index = (i-mx)*d.y+j-my;
				x.next[index] = grid[i][j];
				grid[i][j] = x;
			}
	}
}
