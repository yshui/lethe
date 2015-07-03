module ast.type;
import ast.symbols;

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
	@property nothrow pure string c_type() const { return "void"; }
	@property nothrow pure TypeBase dup() const { return new TypeBase; }
	nothrow void solidify(const(Symbols) s) { };
}

class Type(string name) : TypeBase {
	Particle p;
	Event e;
	//User defined type
	override void solidify(const(Symbols) s) {
		auto d = s.lookup(name);
		assert(d !is null, "Type "~name~" is not defined");
		p = cast(Particle)d;
		e = cast(Event)d;
		assert(p !is null || e !is null, name~" is not a particle or event definition");
	}
	override int dimentsion() const {
		return 1;
	}
	override string str() const {
		return "UD "~name;
	}
	override string c_type() const {
		if (p !is null)
			return "struct "~name~"*";
		if (e !is null)
			return "struct event_"~name~"*";
		assert(false);
	}
	this(Particle xp, Event xe) {
		e = xe;
		p = xp;
	}
	override TypeBase dup() const {
		return new Type!name(p, e);
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

class ParticleType : TypeBase { }
///Define a type match pattern: if input types match T..., then the output type is Result
class TypePattern(Result, T...) { }
