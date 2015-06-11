module scene.balls;
import scene.scene;
import scene.collision;
import engine;
import gfm.math;
immutable float[4] dx = [-1, -1, 1, 1];
immutable float[4] dy = [1, -1, -1, 1];
immutable int[6] quad_index = [0, 1, 2, 0, 2, 3];
class Wall : Particle {
	private vec2f[3] point;
	private int type;
	override @nogc size_t hitbox(Hitbox[] hb) {
		hb[0] = Hitbox(point[]);
		return 1;
	}
	this(int t, box2f g) {
		switch(t) {
			case 0: case 3:
				point[0] = g.min;
				break;
			case 1: case 2:
				point[0] = g.max;
				break;
			default:
				assert(0);
		}
		switch(t) {
			case 0: case 1:
				point[1].x = g.min.x;
				point[1].y = g.max.y;
				break;
			case 2: case 3:
				point[1].x = g.max.x;
				point[1].y = g.min.y;
				break;
			default:
				assert(0);
		}
		point[2] = (point[0]+point[1])/2.0;
		type = t;
	}
}
class Ball : Particle {
	private {
		vec2f center, velocity, newv;
		float r, av, angle;
		bool need_update;
	}
	override nothrow pure @nogc void update() {
		if (need_update) {
			need_update = false;
			velocity = newv;
		}
		center += velocity;
		angle += av;
	}
	override nothrow pure @nogc size_t hitbox(Hitbox[] hb) {
		hb[0] = Hitbox(center, r);
		return 1;
	}
	override nothrow size_t gen_scene(BufferMapping!Vertex vab, BufferMapping!GLuint ibuf) {
		auto tmp = vab.n;
		foreach(i; 0..4) {
			vab.last.position = vec2f(dx[i]*r, dy[i]*r);
			vab.last.translate = center;
			vab.last.texture_coord = vec2f(dx[i], dy[i]);
			vab.last.angle = angle;
			vab.bump();
		}

		foreach(i; 0..6) {
			ibuf.last = cast(uint)(tmp+quad_index[i]);
			ibuf.bump();
		}
		return 6;
	}
	override @nogc nothrow void collide(Particle bp) {
		auto b = cast(Ball)bp;
		auto w = cast(Wall)bp;
		if (b !is null) {
			auto line = b.center-center;
			float dist = center.distanceTo(b.center);
			import std.conv;
			float vm = line.dot(velocity)/dist, vo = line.dot(b.velocity)/dist;
			//import std.stdio;
			//writefln("Ball at %s,%s collide with %s,%s, dist %s", center.x, center.y, b.center.x, b.center.y, dist);
			if (vo-vm > 0) {
				//writeln("Coming apart");
				//Don't count as collide if two balls are coming apart
				return;
			}
			auto rvm = (need_update ? newv : velocity)-(vm*line/dist);
			newv = rvm+(vo*line/dist);
			need_update = true;
		} else if (w !is null) {
			switch(w.type) {
				case 0:
					if (velocity.x < 0)
						velocity.x = -velocity.x;
					break;
				case 1:
					if (velocity.y > 0)
						velocity.y = -velocity.y;
					break;
				case 2:
					if (velocity.x > 0)
						velocity.x = -velocity.x;
					break;
				case 3:
					if (velocity.y < 0)
						velocity.y = -velocity.y;
					break;
				default:
					assert(0);
			}
		} else
			assert(0);
	}
	this(vec2f c, vec2f v, float ir, float iav = 0, float a = 0) {
		center = c;
		velocity = v;
		r = ir;
		angle = a;
		av = iav;
		need_update = false;
	}
}
