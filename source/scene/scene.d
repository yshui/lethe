module scene.scene;
import gfm.math;
import std.math;
import engine;
import std.typecons;
import scene.collision;
import dioni;
class Particle {
	pure nothrow @nogc
	size_t hitbox(Hitbox[] hb) { return 0; }
	pure nothrow @nogc void update() { }
	pure nothrow @nogc void collide(Particle other) { }
	pure nothrow size_t gen_scene(BufferMapping!vertex_ballv vab, BufferMapping!GLuint ib) { return 0; }
}
class Scene(int max_particles, int hitboxes_per_particle) {
	Particle[max_particles] ps;
	private {
		CollisionTarget ct;
		Hitbox[hitboxes_per_particle] hb;
		int width, height;
	}
	void update() {
		ct.reinitialize();
		foreach(p; ps) {
			if (p is null)
				continue;
			p.update();
			auto nhb = p.hitbox(hb);
			foreach(i; 0..nhb)
				ct.insert_hitbox(hb[i], p);
		}
		foreach(p; ps) {
			if (p is null)
				continue;
			auto nhb = p.hitbox(hb);
			auto q = ct.query(hb[0..nhb], p);
			foreach(xp; q)
				p.collide(xp);
		}
	}
	nothrow size_t gen_scene(BufferMapping!vertex_ballv va, BufferMapping!GLuint ibuf) {
		size_t s = 0;
		foreach(p; ps) {
			if (p is null)
				continue;
			s += p.gen_scene(va, ibuf);
		}
		return s;
	}
	this(int W, int H) {
		ct = new CollisionTarget(W, H);
		width = W;
		height = H;
	}
}
