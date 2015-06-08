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
	@nogc ref void opOpAssign(string op, O)(O other) nothrow
	if (op == "+") {
		static if (is(O: BaseSceneData)){
			this += other.vs[];
			this += other.indices[];
		} else static if (isInputRange!O) {
			static assert(hasLength!O);
			static if (is(ElementType!O == Vertex)) {
				foreach(ref v; other) {
					if (vsize >= n)
						return;
					vs[vsize++] = v;
				}
			} else static if (is(ElementType!O == GLuint)) {
				//We are doing triangles
				assert(other.length % 3 == 0);
				foreach(i; other) {
					if (isize >= m) {
						isize -= isize % 3;
						return;
					}
					indices[isize++] = i;
				}
			}
		}
	}
	@nogc void clear_scene() {
		isize = 0;
		vsize = 0;
	}
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
	}
	void load_program(string code) {
		prog = new GLProgram(gl, code);
	}
	~this() {
		win.close();
	}
	void run(uint fps) {
		win.setTitle("Lethe");
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		gl.runtimeCheck();
		glBlendEquation(derelict.opengl3.constants.GL_FUNC_ADD);
		gl.runtimeCheck();
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
			glClearColor(0,0,0,1.0);
			glClear(GL_COLOR_BUFFER_BIT);
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
	}
}