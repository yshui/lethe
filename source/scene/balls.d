module scene.balls;
import scene.scene;
import engine;
import gfm.math;
immutable float[4] dx = [-1, -1, 1, 1];
immutable float[4] dy = [1, -1, -1, 1];
immutable int[6] quad_index = [0, 1, 2, 0, 2, 3];
class Ball(int n, int m) : Particle!(n, m) {
	private {
		vec2f center, velocity;
		float r, av, angle;
	}
	override @nogc void update() {
		center += velocity;
		angle += av;
	}
	override @nogc size_t hitbox(Hitbox[] hb) {
		hb[0] = Hitbox(center, r);
		return 1;
	}
	override @nogc void gen_scene(BaseSceneData!(n, m) sd) {
		Vertex[4] vs;
		foreach(i; 0..4) {
			vs[i].position = vec2f(dx[i]*r, dy[i]*r);
			vs[i].translate = center;
			vs[i].texture_coord = vec2f(dx[i], dy[i]);
			vs[i].angle = angle;
		}

		GLuint tmp = sd.vsize;
		sd += vs[];

		GLuint[6] inds;
		foreach(i; 0..6)
			inds[i] = tmp+quad_index[i];
		sd += inds[];
	}
	this(vec2f c, vec2f v, float ir, float iav = 0, float a = 0) {
		center = c;
		velocity = v;
		r = ir;
		angle = a;
		av = iav;
	}
}
