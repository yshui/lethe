import std.stdio, std.typecons;
import gfm.sdl2;
import gfm.logger;
import gfm.math;
import engine;
import scene.scene,
       scene.balls;
//import std.algorithm;
import std.random;
import std.math;
import derelict.opengl3.gl3;
import std.experimental.logger;

struct uni {
	GLTexture2D tex;
	float w, h;
}


enum np = 4100;

class EngineM : Engine!(np*4, np*6, uni) {
	private {
		alias S = Scene!(np, np);
		S scene;
		GLTexture tex;
	}
	this(Logger logger, int w, int h) {
		super(logger, w, h);
		scene = new S(w, h);
		foreach(i; 0..4000) {
			auto dir = uniform(0, 2*3.14159265358);
			auto absv = uniform(0.5, 1);
			auto v = vec2f(absv*sin(dir), absv*cos(dir));
			auto c = vec2f(uniform(40.0, cast(float)(w-40)),
					uniform(40.0, cast(float)(h-40)));
			scene.ps[i] = new Ball(c, v, uniform(2.0, 5.0), 4);
		}
		//Add four walls
		box2f playground = box2f(vec2f(20, 20), vec2f(w-20, h-20));
		foreach(i; 0..4)
			scene.ps[4000+i] = new Wall(i, playground);
		u.tex = new_texture2d("ball.png");
		u.tex.setMinFilter(GL_LINEAR_MIPMAP_NEAREST);
		u.tex.setMagFilter(GL_LINEAR);
		u.w = w;
		u.h = h;
	}
	override int next_frame() {
		scene.update();
		return 0;
	}
	override int handle_event(ref SDL_Event e) {
		switch (e.type) {
		case SDL_KEYDOWN:
			auto ks = key_state();
			if (ks.isPressed(SDLK_ESCAPE))
				quitting = true;
			break;
		default:
			break;
		}
		return 0;
	}
	override size_t gen_scene(VAMap vab, IMap ib) {
		return scene.gen_scene(vab, ib);
	}

}

void main() {
	auto logger = new ConsoleLogger();
	auto eng = scoped!EngineM(logger, 800, 600);

	auto prog = "#version 140\n#if VERTEX_SHADER\n" ~ import("vs.glsl") ~
		    "\n#elif FRAGMENT_SHADER\n" ~ import("frag.glsl") ~ "\n#endif";
	eng.load_program(prog);
	eng.run(60);
}
