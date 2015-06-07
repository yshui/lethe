module engine.engine;
import engine.vertex;
import std.typecons,
       std.traits,
       std.typetuple,
       std.experimental.logger;
import gfm.sdl2;
import engine.opengl,
       engine.program,
       engine.texture;
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

class BaseSceneData(int n, int m) {
	Vertex[n] vs;
	GLuint[m] indices;
	int vsize, isize;
	void assign_uniforms(OpenGL gl, GLProgram prog) { }
}

class SceneData(int n, int m, Uniforms) : BaseSceneData!(n, m) {
	Uniforms u;
	this(Uniforms _u) { u = _u; }
	this() { }
	override void assign_uniforms(OpenGL gl, GLProgram prog) {
		//Activate all textures
		static if (is(Uniforms == struct) || is(Uniforms == class)) {
			alias TT = FieldTypeTuple!Uniforms;
			int tu = GL_TEXTURE0;
			foreach (member; __traits(allMembers, Uniforms)) {
				mixin("alias T = typeof(Uniforms." ~ member ~ ");");
				static if (staticIndexOf!(T, TT) != -1) {
					static if (is(T: GLTexture)) {
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

class Engine(int n, int m) {
	int delegate() next_frame = null;
	int delegate(ref SDL_Event) handle_event = null;
	BaseSceneData!(n, m) delegate() gen_scene = null;
	bool quitting;
	@property int width() const {
		return _width;
	}
	@property int height() const {
		return _height;
	}
	this(Logger logger) {
		sdl2 = new SDL2(logger);
		sdl2img = new SDLImage(sdl2);
		gl = new OpenGL(logger);

		sdl2.subSystemInit(SDL_INIT_VIDEO);
		sdl2.subSystemInit(SDL_INIT_EVENTS);

		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

		win = new SDL2Window(sdl2, SDL_WINDOWPOS_CENTERED,
				     SDL_WINDOWPOS_CENTERED, 800, 600,
				     SDL_WINDOW_OPENGL);
		_width = 800;
		_height = 600;
		gl.reload();
		gl.redirectDebugOutput();

		gen_format(SDL_PIXELFORMAT_RGBA8888, &fmt);
	}
	void load_program(string code) {
		prog = new GLProgram(gl, code);
	}
	~this() {
		win.close();
	}
	void run(uint fps) {
		win.setTitle("Lethe");
		float x = 0;
		float dx = 0.01;
		while(true) {
			uint frame_start = SDL_GetTicks();
			if (handle_event) {
				auto es = scoped!SDL2EventRange(sdl2);
				foreach(e; es) {
					handle_event(e);
				}
			} else
				sdl2.processEvents();
			if (sdl2.wasQuitRequested() || quitting)
				break;
			if (next_frame)
				next_frame();
			glViewport(0, 0, _width, _height);
			glClearColor(1.0,x,1.0-x,1.0);
			glClear(GL_COLOR_BUFFER_BIT);
			x+=dx;
			if (x > 1.0 || x < 0)
				dx=-dx;
			if (gen_scene) {
				auto d = gen_scene();
				d.assign_uniforms(gl, prog);

				GLuint ibuf;
				glGenBuffers(1, &ibuf);
				glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibuf);
				glBufferData(GL_ELEMENT_ARRAY_BUFFER, GLuint.sizeof*d.isize,
					     d.indices.ptr, GL_STREAM_DRAW);
				gl.runtimeCheck();

				auto va = VertexArray!Vertex(d.vs[0..d.vsize], prog);

				prog.use();
				glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibuf);
				gl.runtimeCheck();
				va.bind();
				glDrawElements(GL_TRIANGLES, d.isize, GL_UNSIGNED_INT, cast(const(void *))0);
				gl.runtimeCheck();
				glDeleteBuffers(1, &ibuf);
				gl.runtimeCheck();
				prog.unuse();
				gl.runtimeCheck();
			}
			win.swapBuffers();
			uint frame_end = SDL_GetTicks();
			uint frame_time = frame_end-frame_start;
			if (frame_time*fps < 1000)
				SDL_Delay(1000/fps-frame_time);
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
		texture.setBaseLevel(0);
		texture.generateMipmap();
		return texture;
	}
	@property SDL2Keyboard key_state() {
		return sdl2.keyboard();
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
	}
}
