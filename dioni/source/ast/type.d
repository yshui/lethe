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

class TypeBase {
	@property nothrow pure @nogc int dimension() const {
		return 0;
	}
	@property nothrow pure TypeBase element_type() const {
		return null;
	}
	@property nothrow pure string str() const { return "void"; }
	@property nothrow pure TypeBase arr_of() const { assert(false); }
	@property nothrow pure string c_type() const { assert(false); }
	@property nothrow pure TypeBase dup() const { return new TypeBase; }
}

class AnonymousType : TypeBase { }

class StateType : TypeBase {
	string name;
	override int dimension() const {
		return 1;
	}
	override string str() const {
		assert(name !is null);
		return "State "~name;
	}
	override TypeBase dup() const {
		return new StateType(name);
	}
	pure nothrow this(string xname) {
		name = xname;
	}
	override string c_type() const {
		return "int";
	}

}

class ParticleType : TypeBase {
	string name;
	const(Particle) p;
	const(Event) e;
	//User defined type
	override int dimension() const {
		return 1;
	}
	override string str() const {
		assert(name !is null);
		return "UD "~name;
	}
	override string c_type() const {
		if (name is null)
			return "struct raw_particle";
		if (p !is null)
			return "struct "~name~"*";
		if (e !is null)
			return "struct event_"~name~"*";
		assert(false);
	}
	nothrow pure this() { name = null; p = null; e = null; }
	pure this(string xname, const(Symbols) s) {
		name = xname;
		auto d = s.lookup(name);
		assert(d !is null, "Type "~name~" is not defined");
		e = cast(Event)d;
		p = cast(Particle)d;
		assert(p !is null || e !is null, name~" is not a particle or event definition");
	}
	nothrow pure this(string xname, const(Particle) xp, const(Event) xe) {
		name = xname;
		p = xp;
		e = xe;
	}
	override TypeBase dup() const {
		if (name !is null)
			return new ParticleType(name, p, e);
		else
			return new ParticleType;
	}
}

class Type(T) : TypeBase
    if (is(T == int) || is(T == float)) {
	override int dimension() const {
		return 1;
	}
	override string str() const {
		return T.stringof;
	}
	override TypeBase arr_of() const {
		return new ArrayType!(Type!T);
	}
	override string c_type() const {
		return T.stringof;
	}
	override TypeBase dup() const {
		return new Type!T;
	}
}

class Type(T, int dim) : TypeBase
    if (is(T == float) && dim > 1) {
	override int dimension() const {
		return dim;
	}
	override string str() const {
		import std.format : format;
		string res;
		try {
			res = format("%s*%s", T.stringof, dim);
		} catch (Exception) {
			res = "Invalid";
		}
		return res;
	}
	override TypeBase arr_of() const {
		return new ArrayType!(Type!(T, dim));
	}
	override string c_type() const {
		import std.format;
		try {
			return format("struct vec%s", dim);
		} catch(Exception) {
			assert(false);
		}
	}
	override TypeBase dup() const {
		return new Type!(T, dim);
	}
}
class ArrayType(ElemType) : TypeBase if (is(ElemType : TypeBase)) {
	override int dimension() const {
		assert(false);
	}
	override @property nothrow pure TypeBase element_type() const {
		return new ElemType();
	}
	override string str() const {
		import std.format : format;
		try {
			return format("ArrayOf %s", element_type.str);
		}catch(Exception) {
			return "Invalid";
		}
	}
	override string c_type() const {
		return "struct list_head";
	}
	override TypeBase dup() const {
		return new ArrayType!ElemType;
	}
	//array of array not supported
}

///Define a type match pattern: if input types match T..., then the output type is Result
class TypePattern(Result, T...) { }
