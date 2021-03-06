module main;
import std.stdio, std.typecons;
import gfm.sdl2;
import gfm.logger;
import gfm.math;
import engine;
//import std.algorithm;
import std.random;
import std.math;
import derelict.opengl3.gl3;
import std.experimental.logger;
import ddioni;

struct uni {
	GLTexture2D tex;
	float w, h;
}


enum np = 1100;

class EngineM : Engine!(np*4, np*6, uni) {
	private GLTexture tex;

	this(Logger logger, int w, int h) {
		super(logger, w, h);
		//new_particle_Bootstrap();
		u.tex = new_texture2d("o.png");
		u.tex.setMinFilter(GL_LINEAR_MIPMAP_NEAREST);
		u.tex.setMagFilter(GL_LINEAR);
		u.w = w;
		u.h = h;
		new_particle_Bootstrap(w, h);
	}
	override int handle_event(ref SDL_Event e) {
		switch (e.type) {
		case SDL_KEYDOWN:
			auto ks = key_state();
			if (ks.isPressed(SDLK_ESCAPE))
				quitting = true;
			else if (ks.isPressed(SDLK_SPACE))
				step = true;
			break;
		default:
			break;
		}
		return 0;
	}

}

void main() {
	auto logger = new ConsoleLogger();
	auto eng = new EngineM(logger, 1280, 960);

	auto prog = "#version 140\n#if VERTEX_SHADER\n" ~ import("vs.glsl") ~
		    "\n#elif FRAGMENT_SHADER\n" ~ import("frag.glsl") ~ "\n#endif";
	eng.load_program(prog);
	eng.run(60);
}
