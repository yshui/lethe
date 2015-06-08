import std.stdio, std.typecons;
import gfm.sdl2;
import gfm.logger;
import gfm.math;
import engine;
import scene.scene,
       scene.balls;
import std.algorithm;
import std.random;
import derelict.opengl3.gl3;

struct uni {
	GLTexture2D tex;
	float w, h;
}

enum np = 100;

void main() {
	auto logger = new ConsoleLogger();
	auto eng = scoped!(Engine!(np*4, np*6))(logger);
	auto sd = new SceneData!(np*4, np*6, uni)();
	auto scene = new Scene!(np, np, np*4, np*6)();
	foreach(i; 0..100) {
		auto v = vec2f(uniform(-1.0, 1.0), uniform(-1.0, 1.0));
		auto c = vec2f(uniform(0.0, cast(float)eng.width),
			       uniform(0.0, cast(float)eng.height));
		scene.ps[i] = new Ball!(np*4, np*6)(c, v, 10, 4);
	}
	int next_frame() {
		scene.update();
		return 0;
	}
	int handle_event(ref SDL_Event e) {
		switch (e.type) {
		case SDL_KEYDOWN:
			auto ks = eng.key_state();
			if (ks.isPressed(SDLK_ESCAPE))
				eng.quitting = true;
			break;
		default:
			break;
		}
		return 0;
	}

	typeof(sd) gen_scene() {
		sd.clear_scene();
		scene.gen_scene(cast(BaseSceneData!(np*4, np*6))sd);
		return sd;
	}
	eng.next_frame = &next_frame;
	eng.handle_event = &handle_event;
	eng.gen_scene = &gen_scene;

	sd.u.tex = eng.new_texture2d("ball.png");
	sd.u.tex.setMinFilter(GL_LINEAR_MIPMAP_NEAREST);
	sd.u.tex.setMagFilter(GL_LINEAR);
	sd.u.w = eng.width();
	sd.u.h = eng.height();

	auto prog = "#version 140\n#if VERTEX_SHADER\n" ~ import("vs.glsl") ~
		    "\n#elif FRAGMENT_SHADER\n" ~ import("frag.glsl") ~ "\n#endif";
	eng.load_program(prog);
	eng.run(60);
}
