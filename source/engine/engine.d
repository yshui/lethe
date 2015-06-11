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
class SDL2EventRange {
	SDL2 sdl2;
	SDL_Event event;
	bool empty;
	this(SDL2 x) {
		sdl2 = x;
		empty = !sdl2.pollEvent(&event);
	}
	@property ref SDL_Event front() {
		return event;
	}
	void popFront() {
		empty = !sdl2.pollEvent(&event);
	}
}

struct Vertex {
	vec2f position;
	vec2f translate;
	vec2f texture_coord;
	float angle;
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
import core.memory;
alias VA = VertexArray!Vertex;
class Engine(int n, int m, Uniforms)
if (is(Uniforms == struct) || is(Uniforms == class)) {
	int next_frame() { return 0; };
	int handle_event(ref SDL_Event) { return 0; };
	size_t gen_scene(VA va, GLBuffer ibuf) { return 0; };
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
		gl.redirectDebugOutput();

		gen_format(SDL_PIXELFORMAT_RGBA8888, &fmt);
		ibuf = new GLBuffer(gl, GL_ELEMENT_ARRAY_BUFFER, m*GLuint.sizeof);
		win.setTitle("Lethe");
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glBlendEquation(derelict.opengl3.constants.GL_FUNC_ADD);
		gl.runtimeCheck();
	}
	void load_program(string code) {
		prog = new GLProgram(gl, code);
		va = new VertexArray!Vertex(gl, prog, n);
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
			auto es = scoped!SDL2EventRange(sdl2);
			foreach(e; es)
				handle_event(e);
			if (sdl2.wasQuitRequested() || quitting)
				break;
			if (next_frame)
				next_frame();
			glViewport(0, 0, _width, _height);
			glClearColor(0,0,0,1.0);
			glClear(GL_COLOR_BUFFER_BIT);
			auto scene_size = gen_scene(va, ibuf);
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
		VertexArray!Vertex va;
		GLBuffer ibuf;
	}
	protected Uniforms u;
}
