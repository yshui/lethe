import std.stdio, std.typecons;
import gfm.opengl;
import gfm.sdl2;
import gfm.logger;
import gfm.math;
import derelict.sdl2.types;
import engine.engine;

void main() {
	auto logger = new ConsoleLogger();
	auto eng = scoped!(Engine!(100, 200))(logger);
	auto scene = new SceneData!(100, 200, void *)(null);
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
	typeof(scene) gen_scene() {
		scene.vsize = 3;
		scene.isize = 3;
		scene.vs[0].position = vec2f(0.0, 0.5);
		scene.vs[1].position = vec2f(-0.5, -0.5);
		scene.vs[2].position = vec2f(0.5, -0.5);
		scene.indices[0] = 0;
		scene.indices[1] = 2;
		scene.indices[2] = 1;
		for (int i = 0; i < 3; i++) {
			scene.vs[i].translate = vec2f(0.0, 0.0);
			scene.vs[i].angle = 0;
		}
		return scene;
	}
	eng.next_frame = &next_frame;
	eng.handle_event = &handle_event;
	eng.gen_scene = &gen_scene;

	auto prog = "#version 140\n#if VERTEX_SHADER\n" ~ import("shader/vs.glsl") ~
		    "\n#elif FRAGMENT_SHADER\n" ~ import("shader/frag.glsl") ~ "\n#endif";
	eng.load_program(prog);
	eng.run();
}
