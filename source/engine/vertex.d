module engine.vertex;
import derelict.opengl3.gl3;
import std.typetuple, std.traits;
import engine.opengl,
       engine.program;
import gfm.math;
private {
	bool isIntegerType(GLenum t) {
		return (t == GL_BYTE
		     || t == GL_UNSIGNED_BYTE
		     || t == GL_SHORT
		     || t == GL_UNSIGNED_SHORT
		     || t == GL_INT
		     || t == GL_UNSIGNED_INT);
	}

	alias VectorTypes = TypeTuple!(byte, ubyte, short, ushort, int, uint, float, double);
	enum GLenum[] VectorTypesGL =
	[
		GL_BYTE,
		GL_UNSIGNED_BYTE,
		GL_SHORT,
		GL_UNSIGNED_SHORT,
		GL_INT,
		GL_UNSIGNED_INT,
		GL_FLOAT,
		GL_DOUBLE
	];

	template typeToGLScalar(T) {
		enum index = staticIndexOf!(T, VectorTypes);
		static if (index == -1) {
			static assert(false, "Could not use " ~ T.stringof ~ " in a vertex description");
		}
		else
			enum typeToGLScalar = VectorTypesGL[index];
	}

	void toGLTypeAndSize(T)(out GLenum type, out int n) {
		alias U = Unqual!T;
		enum index = staticIndexOf!(U, VectorTypes);
		pragma(msg, "X" ~ U.stringof, index);

		static if (isStaticArray!U) {
			type = typeToGLScalar(typeof(T[0]));
			n = U.length;
			pragma(msg, "static array");
		} else static if (index != -1) {
			pragma(msg, "plain type");
			type = VectorTypesGL[index];
			n = 1;
		} else {
			pragma(msg, "vectors");
			// is it a gfm.vector.Vector?
			foreach(int t, S ; VectorTypes) {
				static if (is (U == Vector!(S, 2))) {
					type = VectorTypesGL[t];
					n = 2;
					return;
				}

				static if (is (U == Vector!(S, 3))) {
					type = VectorTypesGL[t];
					n = 3;
					return;
				}

				static if (is (U == Vector!(S, 4))) {
					type = VectorTypesGL[t];
					n = 4;
					return;
				}
			}

			assert(false, "Could not use " ~ T.stringof ~ " in a vertex description");
		}
	}
}
struct Normalized {}
private template Tuple (T...) {
	alias Tuple = T;
}
struct VertexArray(Vertex) {
	GLuint buf;
	GLuint vao;
	this(Vertex[] vs, GLProgram prog) {
		glGenBuffers(1, &buf);
		glBindBuffer(GL_ARRAY_BUFFER, buf);
		glBufferData(GL_ARRAY_BUFFER, vs.length*Vertex.sizeof, vs.ptr, GL_STREAM_DRAW);
		glGenVertexArrays(1, &vao);
		glBindVertexArray(vao);
		alias TT = FieldTypeTuple!Vertex;
		foreach (member; __traits(allMembers, Vertex)) {
			mixin("alias T = typeof(Vertex." ~ member ~ ");");
			static if (staticIndexOf!(T, TT) != -1) {
				auto loc = prog.attrib(member).location;
				if (loc == GLAttribute.fakeLocation)
					continue;
				mixin("enum size_t offset = Vertex." ~ member ~ ".offsetof;");
				int n;
				GLenum type;
				toGLTypeAndSize!T(type, n);

				mixin("alias UDAs = Tuple!(__traits(getAttributes, Vertex." ~ member ~ "));");
				pragma(msg, UDAs);
				bool normalize = staticIndexOf!(Normalized, UDAs) == -1 ? GL_FALSE : GL_TRUE;
				glEnableVertexAttribArray(loc);
				glVertexAttribPointer(loc, n, type, normalize, Vertex.sizeof, cast(GLvoid *)offset);
			}
		}
	}
	void bind() {
		glBindVertexArray(vao);
	}
	~this() {
		glDeleteVertexArrays(1, &vao);
		glDeleteBuffers(1, &buf);
	}
}
