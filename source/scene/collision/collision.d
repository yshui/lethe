module scene.collision.collision;
import scene.collision;
import scene.collision.spatial_hash;
import scene.scene;
import gfm.math;
enum hb_threshold = 10;
struct SimpleHBP {
	Hitbox hb;
	BaseParticle p;
	box2f aabb;
}
class CollisionRangeS : CollisionRange{
	private {
		CollisionTarget ct;
		ulong index;
		box2f[] aabb;
		const(Hitbox)[] hitbox;
		const(BaseParticle) self;
	}

	pure nothrow this(CollisionTarget xct, const(Hitbox)[] hb, const(BaseParticle) iself) {
		ct = xct;
		index = 0;
		self = iself;
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
	override pure nothrow @nogc BaseParticle front() {
		return ct.hb[index].p;
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
		alias SH = SpatialHash!(30, 30);
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
	nothrow pure void insert_hitbox(in ref Hitbox xhb, BaseParticle p) {
		if (hbcnt == hb_threshold) {
			if (sh is null)
				sh = new SH(w, h);
			else
				sh.reinitialize();
			foreach(x; hb)
				sh.insert_hitbox(x.hb, x.p);
		}
		if (hbcnt >= hb_threshold)
			sh.insert_hitbox(xhb, p);
		else {
			hb[hbcnt].hb = xhb;
			hb[hbcnt].p = p;
		}
		hbcnt++;
	}
	nothrow pure CollisionRange query(const(Hitbox)[] hb, const(BaseParticle) iself) {
		if (hbcnt <= hb_threshold)
			return new CollisionRangeS(this, hb, iself);
		else
			return new SpatialRange!(30, 30)(sh, hb, iself);
	}
}
