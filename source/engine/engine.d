module engine.engine;
import engine.vertex;
import std.typecons,
       std.traits,
       std.typetuple,
       std.experimental.logger,
       std.range;
import gfm.sdl2;
import engine.opengl,
       engine.program,
       engine.texture,
       engine.buffer;
import gfm.logger;
import gfm.math;
import derelict.sdl2.types;
import derelict.opengl3.gl,
       derelict.opengl3.gl3;
import dioni;
import collision;
auto event_range(SDL2 sdl2) {
	struct SDL2EventRange {
		SDL_Event event;
		bool empty;
		@property ref SDL_Event front() {
			return event;
		}
		void popFront() {
			empty = !sdl2.pollEvent(&event);
		}
	}
	SDL2EventRange er;
	er.popFront();
	return er;
}

private void gen_format(uint type, SDL_PixelFormat *x) {
	x.format = type;
	int bpp;
	SDL_PixelFormatEnumToMasks(type,
				   &bpp,
				   &x.Rmask,
				   &x.Gmask,
				   &x.Bmask,
				   &x.Amask);
	x.BitsPerPixel = cast(ubyte)bpp;
	x.BytesPerPixel = x.BitsPerPixel/8;
	x.palette = null;
}
private void gen_collision(CollisionTarget ct) {
	ct.reinitialize();
	auto p = first_particle();
	while(p !is null) {
		auto dioni_hb = harvest_hitboxes(p);
		Hitbox[] hbs;
		while(dioni_hb !is null) {
			auto hb = Hitbox(dioni_hb);
			hbs ~= [hb];
			dioni_hb = next_hitbox(dioni_hb);
		}
		dioni_hb = null;
		auto cr = ct.query(hbs, p);
		foreach(col; cr) {
			auto e = alloc_event();
			e.tgtt = dioniEventTarget.Particle;
			e.target = cast(size_t)p;
			e.event_type = dioniEventType.Collide;
			e.v.Collide.m0 = cast(size_t)col;
			queue_event(e);

			e = alloc_event();
			e.tgtt = dioniEventTarget.Particle;
			e.target = cast(size_t)col;
			e.event_type = dioniEventType.Collide;
			e.v.Collide.m0 = cast(size_t)p;
			queue_event(e);

			e = null;
		}
		foreach(ref hb; hbs)
			ct.insert_hitbox(hb, p);
		p = next_particle(p);
	}
}
import core.memory;
alias VA = VertexArray!vertex_ballv;
class Engine(int n, int m, Uniforms)
if (is(Uniforms == struct) || is(Uniforms == class)) {
	private CollisionTarget ct;
	int handle_event(ref SDL_Event) { return 0; };
	bool quitting;
	@property int width() const {
		return _width;
	}
	@property int height() const {
		return _height;
	}
	this(Logger logger, int w = 640, int h = 480) {
		sdl2 = new SDL2(null);
		sdl2img = new SDLImage(sdl2);
		gl = new OpenGL(logger);

		sdl2.subSystemInit(SDL_INIT_VIDEO);
		sdl2.subSystemInit(SDL_INIT_EVENTS);

		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

		win = new SDL2Window(sdl2, SDL_WINDOWPOS_CENTERED,
				     SDL_WINDOWPOS_CENTERED, w, h,
				     SDL_WINDOW_OPENGL);
		_width = w;
		_height = h;
		gl.reload();
		//gl.redirectDebugOutput();

		gen_format(SDL_PIXELFORMAT_RGBA8888, &fmt);
		ibuf = new GLBuffer(gl, GL_ELEMENT_ARRAY_BUFFER, m*GLuint.sizeof);
		win.setTitle("Lethe");
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glBlendEquation(derelict.opengl3.constants.GL_FUNC_ADD);
		gl.runtimeCheck();

		ct = new CollisionTarget(w, h);
	}
	void load_program(string code) {
		prog = new GLProgram(gl, code);
		va = new VertexArray!vertex_ballv(gl, prog, n);
	}
	final void assign_uniforms() {
		static if (is(Uniforms == struct) || is(Uniforms == class)) {
			alias TT = FieldTypeTuple!Uniforms;
			int tu = GL_TEXTURE0;
			foreach (member; __traits(allMembers, Uniforms)) {
				mixin("alias T = typeof(Uniforms." ~ member ~ ");");
				static if (staticIndexOf!(T, TT) != -1) {
					static if (is(T: GLTexture)) {
						//Assign to texture unit
						glActiveTexture(tu);
						gl.runtimeCheck();
						mixin("u." ~ member ~ ".bind();");
						mixin("prog.uniform(\"" ~ member ~ "\").set(tu-GL_TEXTURE0);");
						tu++;
					} else
						mixin("prog.uniform(\"" ~ member ~ "\").set(u." ~ member ~ ");");
				}
			}
		}
	}
	~this() {
		win.close();
	}
	void run(uint fps) {
		assert(prog !is null);
		float max_frame_time = 1000.0/fps;
		//GC.disable();
		while(true) {
			uint frame_start = SDL_GetTicks();
			auto es = sdl2.event_range(); //scoped!SDL2EventRange(sdl2);
			foreach(e; es)
				handle_event(e);
			if (sdl2.wasQuitRequested() || quitting)
				break;

			gen_collision(ct);

			auto ev = alloc_event();
			ev.tgtt = dioniEventTarget.Global;
			ev.event_type = dioniEventType.nextFrame;
			queue_event(ev);
			ev = null; //Prevent GC from collecting malloc memory

			va.dioni_buf_bind();
			ibuf.dioni_indices_bind();

			tick_start();
			auto scene_size = render_queue_get_nind(0);

			va.dioni_buf_unbind();
			ibuf.dioni_indices_unbind();

			glViewport(0, 0, _width, _height);
			glClearColor(0,0,0,1.0);
			glClear(GL_COLOR_BUFFER_BIT);
			assign_uniforms();
			prog.use();
			ibuf.bind();
			va.bind();

			glDrawElements(GL_TRIANGLES, cast(int)scene_size, GL_UNSIGNED_INT, cast(const(void *))0);
			va.unbind();
			ibuf.unbind();
			prog.unuse();
			uint frame_time = SDL_GetTicks()-frame_start;
			bool run_gc = false;
			import std.stdio;
			if (frame_time < max_frame_time)
				SDL_Delay(cast(uint)(max_frame_time-frame_time));
			else
				writefln("Warn: frame time %s > %s, %s", frame_time, max_frame_time, run_gc);
			win.swapBuffers();
		}
	}
	GLTexture2D new_texture2d() {
		return new GLTexture2D(gl);
	}
	GLTexture2D new_texture2d(const(string) file) {
		auto image = sdl2img.load("ball.png");//.convert(&fmt);
		auto texture = new_texture2d();
		image.lock();
		texture.setImage(0, GL_RGBA8, image.width, image.height, GL_RGBA, GL_UNSIGNED_BYTE, image.pixels());
		image.unlock();
		image.close();
		texture.setBaseLevel(0);
		texture.generateMipmap();
		return texture;
	}
	@property SDL2Keyboard key_state() {
		return sdl2.keyboard();
	}
	@property int height() {
		return _height;
	}
	@property int width() {
		return _width;
	}
	private {
		SDL2Window win;
		SDL2 sdl2;
		SDLImage sdl2img;
		OpenGL gl;
		SDL2GLContext glctx;
		int _width, _height;
		GLProgram prog;
		SDL_PixelFormat fmt;
		VertexArray!vertex_ballv va;
		GLBuffer ibuf;
	}
	protected Uniforms u;
}
