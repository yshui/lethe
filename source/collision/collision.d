module collision.collision;
import collision;
import gfm.math;
enum hb_threshold = 10;
struct SimpleHBP {
	Hitbox hb;
	int id;
	box2f aabb;
}
class CollisionRangeS : CollisionRange{
	private {
		CollisionTarget ct;
		ulong index;
		box2f[] aabb;
		const(Hitbox)[] hitbox;
		int self;
	}

	pure nothrow this(CollisionTarget xct, const(Hitbox)[] hb, int id) {
		ct = xct;
		index = 0;
		self = id;
		hitbox = hb;
		aabb.length = hb.length;
		foreach(i; 0..hb.length)
			aabb[i] = hb[i].aabb;
	}
	~this() {
		aabb.length = 0;
	}
	override pure nothrow @nogc bool empty() {
		return index < ct.hbcnt;
	}
	override pure nothrow @nogc int front() {
		return ct.hb[index].id;
	}
	override pure nothrow @nogc void popFront() {
		indexloop: do {
			index++;
			if (ct.hb[index].p is self)
				continue;
			foreach(i; 0..aabb.length) {
				if (!aabb[i].intersects(ct.hb[index].aabb))
					continue;
				if (hitbox[i].collide(ct.hb[index].hb))
					break indexloop;
			}
		} while(index < ct.hbcnt);
	}
}
class CollisionTarget {
	private {
		alias SH = SpatialHash!(50, 50);
		SH sh;
		SimpleHBP[hb_threshold] hb;
		box2f whole;
		int hbcnt;
		int w, h;
	}
	pure nothrow @nogc void reinitialize() {
		hbcnt = 0;
		if (sh !is null)
			sh.reinitialize();
	}
	this(int W, int H) {
		hbcnt = 0;
		w = W;
		h = H;
	}
	nothrow pure void insert_hitbox(in ref Hitbox xhb, int id) {
		if (hbcnt == hb_threshold) {
			if (sh is null)
				sh = new SH(w, h);
			else
				sh.reinitialize();
			foreach(x; hb)
				sh.insert_hitbox(x.hb, x.id);
		}
		if (hbcnt >= hb_threshold)
			sh.insert_hitbox(xhb, id);
		else {
			hb[hbcnt].hb = xhb;
			hb[hbcnt].id = id;
		}
		hbcnt++;
	}
	nothrow pure CollisionRange query(const(Hitbox)[] hb, int self_id) {
		if (hbcnt <= hb_threshold)
			return new CollisionRangeS(this, hb, self_id);
		else
			return new SpatialRange!(50, 50)(sh, hb, self_id);
	}
}
