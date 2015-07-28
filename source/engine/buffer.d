module engine.buffer;

import derelict.opengl3.gl3;

import engine.opengl;
import core.exception;
import std.typecons;
import dioni;

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
		void dioni_buf_bind(T)() {
			void *buf = glMapBuffer(_target, GL_WRITE_ONLY);
			assert(_size % T.sizeof == 0);
			render_queue_bind_buf(0, buf, _size/T.sizeof);
		}
		void dioni_buf_unbind() {
			render_queue_bind_buf(0, null, 0);
		}
		void dioni_indices_bind() {
			void *buf = glMapBuffer(_target, GL_WRITE_ONLY);
			assert(_size % GLuint.sizeof == 0);
			render_queue_bind_indices(0, cast(uint*)buf, _size/GLuint.sizeof);
		}
		void dioni_indices_unbind() {
			render_queue_bind_indices(0, null, 0);
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
