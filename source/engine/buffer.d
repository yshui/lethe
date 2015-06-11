module engine.buffer;

import derelict.opengl3.gl3;

import engine.opengl;
import core.exception;
import std.typecons;

class BufferMapping(T) {
	private {
		T *buf;
		size_t size;
		size_t top;
		GLBuffer src;
	}
	@property pure nothrow @nogc size_t n() {
		return top;
	}
	ref T opIndex(size_t i) pure {
		if (buf is null || i >= size)
			throw new RangeError();
		return *(buf+i);
	}
	void opIndexAssign(ref T data, size_t i) {
		opIndex(i) = data;
	}
	this(GLBuffer ibuf, GLenum access) {
		import std.stdio;
		ibuf.bind();
		buf = cast(T*)glMapBuffer(ibuf._target, access);
		size = ibuf._size/T.sizeof;
		src = ibuf;
	}
	@property nothrow pure ref T last() {
		import std.conv;
		assert(top < size, to!string(top));
		if (top >= size)
			throw new RangeError();
		return *(buf+top);
	}
	nothrow pure @nogc void bump() {
		top++;
	}
	void unmap() {
		if (buf is null)
			return;
		assert(src !is null);
		src.bind();
		glUnmapBuffer(src._target);
		buf = null;
	}
	~this() {
		unmap();
	}
}

/// OpenGL Buffer wrapper.
final class GLBuffer {
	public {
		/// Creates an empty buffer.
		/// Throws: $(D OpenGLException) on error.
		this(OpenGL gl, GLuint target, size_t size) {
			_gl = gl;
			_target = target;
			_firstLoad = true;

			glGenBuffers(1, &_buffer);
			bind();
			glBufferData(target, size, null, GL_DYNAMIC_DRAW);
			gl.runtimeCheck();
			_size = size;
		}

		~this() {
			close();
		}

		/// Releases the OpenGL buffer resource.
		private nothrow @nogc void close() {
			glDeleteBuffers(1, &_buffer);
		}

		/// Returns: Size of buffer in bytes.
		@property size_t size() pure const nothrow @nogc {
			return _size;
		}

		/// Binds this buffer.
		/// Throws: $(D OpenGLException) on error.
		void bind() {
			glBindBuffer(_target, _buffer);
			_gl.runtimeCheck();
		}

		/// Unbinds this buffer.
		/// Throws: $(D OpenGLException) on error.
		void unbind() const nothrow @nogc {
			glBindBuffer(_target, 0);
		}

		/// Returns: Wrapped OpenGL resource handle.
		@property GLuint handle() pure const nothrow @nogc {
			return _buffer;
		}
		auto map(T)(GLenum access) {
			return scoped!(BufferMapping!T)(this, access);
		}
		auto read_map(T)() {
			return map!T(GL_READ_ONLY);
		}
		auto write_map(T)() {
			return map!T(GL_WRITE_ONLY);
		}
	}

	private {
		OpenGL _gl;
		GLuint _buffer;
		size_t _size;
		GLuint _target;
		bool _firstLoad;
		bool _initialized;
	}
}
