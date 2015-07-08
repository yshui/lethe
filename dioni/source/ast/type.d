module ast.type;
import ast.symbols, ast.decl;

pure TypeBase type_matching(T...)(const(TypeBase)[] ity) {
	pattern_loop: foreach(tp; T) {
		static if (is(tp: TypePattern!M, M...)) {
			assert(ity.length+1 == M.length);
			//Generate a "if"
			foreach(i, ty; M[1..$])
				if (cast(ty)ity[i] is null)
					continue pattern_loop;
			alias res = M[0];
			return new res;
		} else
			static assert(false, tp.stringof);
	}
	string exc = "No type match found";
	foreach(n; ity)
		exc ~= ", " ~ n.str;
	throw new Exception(exc);
}

abstract class TypeBase {
	@property nothrow pure @safe {
		@nogc int dimension() const {
			return 0;
		}
		TypeBase element_type() const {
			return null;
		}
		string str() const { return "void"; }
		TypeBase arr_of() const { assert(false); }
		string c_type() const { assert(false); }
		TypeBase dup() const { assert(false); }
	}
}

class AnonymousType : TypeBase { }

class ParticleHandle : TypeBase {
override :
	string c_type() const { return "int"; }
	TypeBase dup() const { return new ParticleType; }
	string str() const { return "ParticleHandle"; }
	bool opEquals(Object o) const {
		return typeid(o) == typeid(ParticleHandle);
	}
}

class StateType : TypeBase {
	string name;
	pure nothrow @safe this(string xname) {
		name = xname;
	}
override :
	int dimension() const {
		return 1;
	}
	string str() const {
		assert(name !is null);
		return "State "~name;
	}
	TypeBase dup() const {
		return new StateType(name);
	}
	string c_type() const {
		return "int";
	}
	bool opEquals(Object o) const {
		auto st = cast(const(StateType))o;
		if (st is null)
			return false;
		return name == st.name;
	}

}

class ParticleType : TypeBase {
	string name;
	const(Particle) p;
	const(Event) e;
	@safe pure {
		nothrow this() { name = null; p = null; e = null; }
		this(string xname, const(Symbols) s) {
			name = xname;
			auto d = s.lookup(name);
			assert(d !is null, "Type "~name~" is not defined");
			e = cast(const(Event))d;
			p = cast(const(Particle))d;
			assert(p !is null || e !is null,
			       name~" is not a particle or event definition");
		}
		nothrow this(string xname, const(Particle) xp, const(Event) xe) {
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
			return new ParticleType(name, p, e);
		else
			return new ParticleType;
	}
	bool opEquals(Object o) const {
		auto pt = cast(const(ParticleType))o;
		if (pt is null)
			return false;
		return name == pt.name;
	}
}

class Type(T) : TypeBase
    if (is(T == int) || is(T == float)) {
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
	bool opEquals(Object o) const {
		return typeid(o) == typeid(Type!T);
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
	bool opEquals(Object o) const {
		return typeid(o) == typeid(Type!(T, dim));
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
	bool opEquals(Object o) const {
		return typeid(o) == typeid(ArrayType!ElemType);
	}
	//array of array not supported
}

///Define a type match pattern: if input types match T..., then the output type is Result
class TypePattern(Result, T...) { }

bool type_compatible(const(TypeBase) src, const(TypeBase) tgt) {
	if (typeid(src) == typeid(tgt))
		return true;
	if (typeid(tgt) == typeid(Type!float))
		return typeid(src) == typeid(Type!int);
	return false;
}
