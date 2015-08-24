module error;
import ast.type;
public import std.exception : enforceEx;
class CompileError : Exception {
	@safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) {
		super("CompileError: "~msg, file, line, next);
	}
}
class OpTypeError : CompileError {
	pure @safe this(string op, const(TypeBase) lhs, const(TypeBase) rhs=null,
	     string file = __FILE__, int line=__LINE__, Throwable next=null) {
		auto msg = "No operator "~op~"found for ("~lhs.str;
		if (rhs !is null)
			msg ~= ", "~rhs.str;
		super(msg~")", file, line, next);
	}
}
class AccessError : CompileError {
	pure @safe nothrow
	this(string var, int at,
	     string file = __FILE__, int line = __LINE__, Throwable next=null) {
		immutable const(char[])[] acc = [ "Read", "Written" ];
		auto msg = "Symbol "~var~" can't be "~acc[at];
		super(msg, file, line, next);
	}
}
class ParamLenError : CompileError {
	pure @safe nothrow
	this(string n, ulong a, ulong b, string file = __FILE__,
	     int line=__LINE__, Throwable next=null) {
		auto msg = n~" takes "~to!string(a)~" parameters, but "~to!string(b)~" passed";
		super(msg, file, line, next);
	}
}
