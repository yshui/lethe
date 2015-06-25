module sdpc.primitives;
import std.algorithm,
       std.stdio,
       std.typetuple,
       std.traits;
package enum Result {
	OK,
	Err
}

private template isVoid(T) {
	static if (is(T == void))
		enum bool isVoid = true;
	else
		enum bool isVoid = false;
}

template ElemType(T) {
	static if (is(T == ParseResult!U, U...)) {
		static if (U.length == 1)
			alias ElemType = U[0];
		else
			alias ElemType = U;
	} else
		static assert(false);
}

private template stripVoid(T...) {
	static if (T.length == 0)
		alias stripVoid = TypeTuple!();
	else static if (is(T[0] == void))
		alias stripVoid = stripVoid!(T[1..$]);
	else
		alias stripVoid = TypeTuple!(T[0], stripVoid!(T[1..$]));
}

template ElemTypes(T...) {
	alias ElemTypes = staticMap!(ElemType, T);
}

template ElemTypesNoVoid(T...) {
	alias ElemTypesNoVoid = stripVoid!(ElemTypes!T);
}

struct ParseResult(T...) {
	Result s;
	size_t consumed;

	static if (T.length == 0 || allSatisfy!(isVoid, T))
		alias T2 = void;
	else static if (T.length == 1)
		alias T2 = T[0];
	else
		alias T2 = T;
	static if (!is(T2 == void)) {
		T2 t;
		static if (T.length == 1) {
			@property T2 result() {
				assert(s == Result.OK);
				return t;
			}
			alias result this;
		} else {
			auto result(int id)() {
				assert(s == Result.OK);
				return t[id];
			}
		}
	}

	@property nothrow pure @nogc ok() {
		return s == Result.OK;
	}

	invariant {
		assert(s == Result.OK || consumed == 0);
	}
}

T ok_result(T: ParseResult!U, U)(U r, size_t consumed) {
	return T(Result.OK, consumed, r);
}

ParseResult!T ok_result(T)(T r, size_t consumed) {
	return ParseResult!T(Result.OK, consumed, r);
}

T err_result(T: ParseResult!U, U)() {
	static if (is(U == void))
		return T(Result.Err, 0);
	else
		return T(Result.Err, 0, U.init);
}

ParseResult!T err_result(T)(T def) if (!is(T == ParseResult!U, U)) {
	return ParseResult!T(Result.Err, 0, def);
}

ParseResult!T err_result(T)() if (!is(T == ParseResult!U, U)) {
	static if (is(T == void))
		return ParseResult!T(Result.Err, 0);
	else
		return ParseResult!T(Result.Err, 0, T.init);
}

ParseResult!T cast_result(T, alias func)(Stream i) if (is(ElemType!(ReturnType!func): T)) {
	auto r = func(i);
	if (!r.ok)
		return err_result!T();
	return ok_result(cast(T)r.result, r.consumed);
}

interface Stream {
	bool starts_with(const char[] prefix);
	string advance(size_t bytes);
	void push();
	void pop();
	void drop();
	void revert();
	void get_pos(out int line, out int col);
	@property bool eof();
	@property pure nothrow @nogc string head();
}

class BufStream: Stream {
	import std.stdio;
	struct Pos {
		string pos;
		int line, col;
	}
	private {
		Pos now;
		Pos[] stack;
	}
	@property pure nothrow @nogc string head() {
		return now.pos;
	}
	override bool starts_with(const char[] prefix) {
		import std.stdio;
		if (prefix.length > now.pos.length)
			return false;
		return now.pos.startsWith(prefix);
	}
	override string advance(size_t bytes) {
		assert(bytes <= now.pos.length);
		auto ret = now.pos[0..bytes];
		foreach(c; ret) {
			now.col++;
			if (c == '\n') {
				now.col = 1;
				now.line++;
			}
		}
		writefln("Eat " ~ ret);
		now.pos = now.pos[bytes..$];
		return ret;
	}
	override void push() {
		stack ~= [now];
	}
	override void pop() {
		now = stack[$-1];
		stack.length--;
	}
	override void drop() {
		stack.length--;
	}
	override void revert() {
		now = stack[$-1];
	}
	override void get_pos(out int line, out int col) {
		line = now.line;
		col = now.col;
	}
	@property override bool eof() {
		return now.pos.length == 0;
	}
	this(string str) {
		now.pos = str;
		now.line = now.col = 1;
	}

}

/*
class Stream {
	private File f;
	char[] buf;
	bool starts_with(const ref string prefix) {
		if (buf.len < prefix.len)
			refill(prefix.len-buf.len);
		if (buf.len < prefix.len)
			return false;
		return buf.startWith(prefix);
	}
	void refill(size_t bytes) {
		size_t pos = buf.len;
		buf.len += bytes;
		auto tmp = f.rawRead(buf[pos..$]);
		if (tmp.len != bytes)
			buf.len = pos+tmp.len;
	}
	void advance(size_t bytes) {
		assert(bytes <= buf.len);
		buf = buf[bytes..$];
	}
	this(File xf) {
		f = xf;
	}
}*/
