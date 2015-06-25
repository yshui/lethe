module sdpc.primitives;
import std.algorithm,
       std.stdio,
       std.typetuple,
       std.traits;
package enum Result {
	OK,
	Err
}

struct ParserMetadata {
	string name;
}

template UDAIndex(alias symbol, alias attribute) {
	import std.typetuple : staticIndexOf;
	import std.traits : staticMap;

	static if (is(attribute == struct) || is(attribute == class)) {
		template GetTypeOrExp(alias S) {
			static if (is(typeof(S)))
				alias GetTypeOrExp = typeof(S);
			else
				alias GetTypeOrExp = S;
		}
		enum int UDAIndex = staticIndexOf!(attribute, staticMap!(GetTypeOrExp,
					__traits(getAttributes, symbol)));
	}
	else
		enum int UDAIndex = staticIndexOf!(attribute, __traits(getAttributes, symbol));
}

template getUDA(alias symbol, alias attribute)
    if (UDAIndex!(symbol, attribute) != -1) {
	enum UDAs = __traits(getAttributes, symbol);
	enum getUDA = UDAs[UDAIndex!(symbol, attribute)];
}

template getParserName(alias symbol) {
	static if (UDAIndex!(symbol, ParserMetadata) != -1) {
		enum pm = getUDA!(symbol, ParserMetadata);
		enum getParserName = pm.name;
	} else
		enum getParserName = __traits(identifier, symbol);
}

template concatParserName(string delim, T...) {
	enum meta = getParserName!(T[0]);
	static if (T.length <= 0)
		enum concatParserName = "";
	else static if (T.length == 1)
		enum concatParserName = meta;
	else
		enum concatParserName = meta ~ delim ~ concatParserName!(delim, T[1..$]);
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
	void rewind(size_t bytes, string caller=__FUNCTION__);
	@property bool eof();
}

class BufStream: Stream {
	import std.stdio;
	private {
		immutable(char)[] buf;
		immutable(char)[] slice;
		size_t offset;
	}
	@property pure nothrow @nogc string head() {
		return slice;
	}
	override bool starts_with(const char[] prefix) {
		import std.stdio;
		if (prefix.length > slice.length)
			return false;
		return slice.startsWith(prefix);
	}
	override string advance(size_t bytes) {
		assert(bytes <= slice.length);
		auto ret = slice[0..bytes];
		writefln("Eat " ~ ret);
		slice = slice[bytes..$];
		offset= bytes;
		return ret;
	}
	override void rewind(size_t bytes, string caller=__FUNCTION__) {
		writefln("Rewind %s, by %s", bytes, caller);
		import std.conv;
		assert(bytes <= offset, to!string(bytes) ~ "," ~ to!string(offset));
		offset -= bytes;
		slice = buf[offset..$];
	}
	@property override bool eof() {
		return slice.length == 0;
	}
	this(string str) {
		buf = str;
		slice = buf[];
		offset = 0;
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
		buf.len= bytes;
		auto tmp = f.rawRead(buf[pos..$]);
		if (tmp.len != bytes)
			buf.len = postmp.len;
	}
	void advance(size_t bytes) {
		assert(bytes <= buf.len);
		buf = buf[bytes..$];
	}
	this(File xf) {
		f = xf;
	}
}*/
