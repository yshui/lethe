module ast.type;
import ast.symbols, ast.decl;

nothrow pure @safe @nogc bool type_match(T, U)(U a) {
	static if (is(U == const(V), V))
		alias S = const(T);
	else static if (is(U == immutable(V), V))
		alias S = immutable(T);
	else
		alias S = T;
	return (cast(S)a) !is null;
}

nothrow pure @safe TypeBase type_calc(T...)(const(TypeBase)[] ity) {
	pattern_loop: foreach(tp; T) {
		static if (is(tp: TypePattern!M, M...)) {
			assert(ity.length+1 == M.length);
			//Generate a "if"
			foreach(i, ty; M[1..$])
				if (!ity[i].type_match!ty)
					continue pattern_loop;
			alias res = M[0];
			return new res;
		} else
			static assert(false, tp.stringof);
	}
	string exc = "No type match found";
	foreach(n; ity)
		exc ~= ", " ~ n.str;
	assert(false, exc);
}

class TypeBase {
	@property nothrow pure @safe {
		@nogc int dimension() const {
			return 0;
		}
		TypeBase element_type() {
			return null;
		}
		string str() const { return "void"; }
		TypeBase arr_of() const { assert(false); }
		string c_type() const { assert(false); }
		TypeBase dup() const { assert(false); }
		bool opEquals(const(TypeBase) tb) const { return false; }
	}
}

class AnonymousType : TypeBase { }

class ParticleHandle : TypeBase {
override :
	string c_type() const { return "int"; }
	TypeBase dup() const { return new ParticleHandle; }
	string str() const { return "ParticleHandle"; }
	bool opEquals(const(TypeBase) o) const {
		return o.type_match!ParticleHandle;
	}
}

mixin template NamedType(T, string n) {
	string name;
	pure nothrow @safe {
		this(string xname) {
			name = xname;
		}
	}
override :
	string str() const {
		assert(name !is null);
		return  n~" "~name;
	}
	TypeBase dup() const {
		return new T(name);
	}
	string c_type() const {
		return "int";
	}
	bool opEquals(const(TypeBase) o) const {
		auto st = cast(const(T))o;
		if (st is null)
			return false;
		return name == st.name;
	}
}

class StateType : TypeBase {
	mixin NamedType!(typeof(this), "State");
}

class TagType : TypeBase {
	mixin NamedType!(typeof(this), "Tag");
}

class EventType : TypeBase {
	mixin NamedType!(typeof(this), "Event");
}

class RangeType : TypeBase {
	const(int) d;
	const(bool) is_int;
	pure nothrow @safe {
		this(int dim, bool i) {
			d = dim;
			is_int = i;
		}
	}
override :
	int dimension() const { return d; }
	string str() const { return "Range"; }
	TypeBase dup() const { return new RangeType(d, is_int); }
	string c_type() const {
		import std.conv : to;
		if (d > 1)
			return "struct range"~to!string(d);
		if (is_int)
			return "struct rangei";
		return "struct rangef";
	}
	bool opEquals(const(TypeBase) t) const {
		auto rt = cast(const(RangeType))t;
		if (rt is null)
			return false;
		return d == rt.d && is_int == rt.is_int;
	}
}

class UDType : TypeBase {
	string name;
	const(Particle) p;
	const(Event) e;
	@safe pure nothrow {
		this() { name = null; p = null; e = null; }
		this(string xname, const(Symbols) s) {
			name = xname;
			auto d = s.lookup(name);
			assert(d !is null, "Type "~name~" is not defined");
			e = cast(const(Event))d;
			p = cast(const(Particle))d;
			assert(p !is null || e !is null,
			       name~" is not a particle or event definition");
		}
		this(string xname, const(Particle) xp, const(Event) xe) {
			name = xname;
			p = xp;
			e = xe;
		}
	}
override :
	//User defined type
	int dimension() const {
		return 1;
	}
	string str() const {
		assert(name !is null);
		return "UD "~name;
	}
	string c_type() const {
		if (name is null)
			return "struct raw_particle";
		if (p !is null)
			return "struct "~name~"*";
		if (e !is null)
			return "struct event_"~name~"*";
		assert(false);
	}
	TypeBase dup() const {
		if (name !is null)
			return new UDType(name, p, e);
		else
			return new UDType;
	}
	bool opEquals(const(TypeBase) o) const {
		auto pt = cast(const(UDType))o;
		if (pt is null)
			return false;
		return name == pt.name;
	}
}

class Type(T) : TypeBase
    if (is(T == int) || is(T == float) || is(T == bool)) {
override :
	int dimension() const {
		return 1;
	}
	string str() const {
		return T.stringof;
	}
	TypeBase arr_of() const {
		return new ArrayType!(Type!T);
	}
	string c_type() const {
		return T.stringof;
	}
	TypeBase dup() const {
		return new Type!T;
	}
	bool opEquals(const(TypeBase) o) const {
		return o.type_match!(Type!T);
	}
}

class Type(T, int dim) : TypeBase
    if (is(T == float) && dim > 1) {
override :
	int dimension() const {
		return dim;
	}
	string str() const {
		import std.format : format;
		string res;
		try {
			res = format("%s*%s", T.stringof, dim);
		} catch (Exception) {
			res = "Invalid";
		}
		return res;
	}
	TypeBase arr_of() const {
		return new ArrayType!(Type!(T, dim));
	}
	string c_type() const {
		import std.format;
		try {
			return format("struct vec%s", dim);
		} catch(Exception) {
			assert(false);
		}
	}
	TypeBase dup() const {
		return new Type!(T, dim);
	}
	bool opEquals(const(TypeBase) o) const {
		return o.type_match!(Type!(T, dim));
	}
}
class ArrayType(ElemType) : TypeBase if (is(ElemType : TypeBase)) {
override :
	int dimension() const {
		assert(false);
	}
	@property nothrow pure TypeBase element_type() const {
		return new ElemType();
	}
	string str() const {
		import std.format : format;
		try {
			return format("ArrayOf %s", element_type.str);
		}catch(Exception) {
			return "Invalid";
		}
	}
	string c_type() const {
		return "struct list_head";
	}
	TypeBase dup() const {
		return new ArrayType!ElemType;
	}
	@safe nothrow pure bool opEquals(Object o) const {
		return o.type_match!(ArrayType!ElemType);
	}
	//array of array not supported
}

///Define a type match pattern: if input types match T..., then the output type is Result
class TypePattern(Result, T...) { }

nothrow pure @safe
bool type_compatible(const(TypeBase) src, const(TypeBase) tgt) {
	if (src.opEquals(tgt))
		return true;
	if (tgt.type_match!(Type!float))
		return src.type_match!(Type!int);
	return false;
}
