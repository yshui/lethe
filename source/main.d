import std.stdio, std.typecons;
import gfm.sdl2;
import gfm.logger;
import gfm.math;
import engine;
import scene.scene,
       scene.balls;
import std.algorithm;
import std.random;
import std.math;
import derelict.opengl3.gl3;

struct uni {
	GLTexture2D tex;
	float w, h;
}

enum np = 400;

void main() {
	auto logger = new ConsoleLogger();
	auto eng = scoped!(Engine!(np*4, np*6))(logger, 800, 600);
	auto sd = new SceneData!(np*4, np*6, uni)();
	auto scene = new Scene!(np, np, np*4, np*6)(eng.width, eng.height);
	foreach(i; 0..300) {
		auto dir = uniform(0, 2*3.14159265358);
		auto absv = uniform(1.5, 3.0);
		auto v = vec2f(absv*sin(dir), absv*cos(dir));
		auto c = vec2f(uniform(40.0, cast(float)(eng.width-40)),
			       uniform(40.0, cast(float)(eng.height-40)));
		scene.ps[i] = new Ball!(np*4, np*6)(c, v, 10, 4);
	}
	//Add four walls
	box2f playground = box2f(vec2f(20, 20), vec2f(eng.width-20, eng.height-20));
	foreach(i; 0..4)
		scene.ps[300+i] = new Wall!(np*4, np*6)(i, playground);
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
