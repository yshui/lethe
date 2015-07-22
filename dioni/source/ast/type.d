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

nothrow pure @safe bool typeid_equals(const(TypeInfo_Class) a, const(TypeInfo_Class) b){
	if (a is b)
		return true;
	return a.info.name == b.info.name;
}

template isPOD(T) {
	static if (is(T == int) || is(T == float) || is(T == bool))
		enum isPOD = true;
	else
		enum isPOD = false;
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
	nothrow pure @safe {
		@nogc int dimension() const {
			return 0;
		}
		TypeBase element_type() {
			return null;
		}
		string str() const { return "void"; }
		TypeBase arr_of() const { assert(false); }
		string c_type() const { assert(false); }
		string d_type() const { assert(false); }
		TypeBase dup() const { assert(false); }
		bool opEquals(const(TypeBase) tb) const { return false; }
		string c_copy(string src, string dst) const {
			return dst~" = "~src;
		}
		string c_cast(const(TypeBase) target, string code) const {
			assert(typeid_equals(typeid(target), typeid(this)), "Can't cast"~
			       " from "~typeid(this).toString~" to "~
			       typeid(target).toString);
			return code;
		}
	}
}

class AnyType : TypeBase { }

class ParticleHandle : TypeBase {
override :
	string c_type() const { return "int"; }
	TypeBase dup() const { return new ParticleHandle; }
	string str() const { return "ParticleHandle"; }
	bool opEquals(const(TypeBase) o) const {
		return o.type_match!ParticleHandle;
	}
	string c_cast(const(TypeBase) target, string code) const {
		if (target.type_match!ParticleHandle)
			return code;
		if (target.type_match!AnyParticle)
			return "get_particle_by_id("~code~")";
		assert(false);
	}
}

class Type(T) : TypeBase
    if (!isPOD!T && is(typeof(T.init.name))) {
	string name;
	const(T) instance;
	pure nothrow @safe {
		this(string xname, const(Symbols) s) {
			//Verify xname actually exists
			auto d = s.lookup_checked(xname);
			auto xd = cast(const(T))d;
			assert(xd !is null);
			instance = xd;
			name = xname;
		}
		this(const(T) i) {
			name = i.name;
			instance = i;
		}
	}
override :
	string c_cast(const(TypeBase) target, string code) const {
		static if (is(T == Particle)) {
			if (target.type_match!AnyParticle)
				return "get_particle_by_id("~code~"->__id)";
		}
		auto x = cast(const(Type!T))target;
		assert(x !is null);
		assert(x.name == name);
		return code;
	}
	string str() const {
		assert(name !is null);
		return  T.stringof~" "~name;
	}
	TypeBase dup() const {
		return new Type!T(instance);
	}
	string c_type() const {
		static if (is(T == Particle))
			return "struct "~name~" *";
		else static if (is(T == Event))
			return "struct event_"~name;
		else
			return "int";
	}
	bool opEquals(const(TypeBase) o) const {
		auto st = cast(const(Type!T))o;
		if (st is null)
			return false;
		return name == st.name;
	}
	string c_copy(string src, string dst) const { assert(false); }
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

class AnyParticle : TypeBase {
override :
	string c_type() const { return "struct particle *"; }
	TypeBase dup() const { return new AnyType; }
}

class Type(T) : TypeBase
    if (isPOD!T) {
override :
	string c_cast(const(TypeBase) target, string code) const {
		static if (!is(T == bool))
			if (target.type_match!(Type!float))
				return code;
		assert(target.type_match!(Type!T));
		return code;
	}
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
	string d_type() const {
		return c_type();
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
	string d_type() const {
		import std.conv : to;
		return "vec"~to!string(dim)~"f";
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

