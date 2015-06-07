import std.stdio, std.typecons;
import gfm.sdl2;
import gfm.logger;
import gfm.math;
import engine;
import std.algorithm;

struct uni {
	GLTexture2D tex;
}


void main() {
	auto logger = new ConsoleLogger();
	auto eng = scoped!(Engine!(100, 200))(logger);
	auto scene = new SceneData!(100, 200, uni)();
	int next_frame() { return 0; }
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

	immutable float[4] dx = [-1, -1, 1, 1];
	immutable float[4] dy = [1, -1, -1, 1];
	immutable int[6] quad_index = [0, 1, 2, 0, 2, 3];
	typeof(scene) gen_scene() {
		return scene;
	}
	scene.vsize = 4;
	scene.isize = 6;
	copy(quad_index[0..6], scene.indices[0..6]);
	foreach(i; 0..4) {
		scene.vs[i].position = vec2f(dx[i]/2, dy[i]/2);
		scene.vs[i].texture_coord = vec2f(dx[i], dy[i]);
		scene.vs[i].translate = vec2f(0, 0);
		scene.vs[i].angle = 0;
	}
	eng.next_frame = &next_frame;
	eng.handle_event = &handle_event;
	eng.gen_scene = &gen_scene;

	scene.u.tex = eng.new_texture2d("ball.png");

	auto prog = "#version 140\n#if VERTEX_SHADER\n" ~ import("vs.glsl") ~
		    "\n#elif FRAGMENT_SHADER\n" ~ import("frag.glsl") ~ "\n#endif";
	eng.load_program(prog);
	eng.run(60);
}
