module ast.type;
import ast.symbols, ast.decl;
import utils;
import std.string : format;
import std.conv : to;
import error;
import std.exception : enforce;

alias ce_on = enforceEx!CompileError;

class CastError : CompileError {
	@safe pure nothrow this(const(TypeBase) src, const(TypeBase) tgt,
		   string file = __FILE__, size_t line = __LINE__) {
		string msg = "Can't cast from "~src.str~" to "~tgt.str;
		super(msg, file, line);
	}
}

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
	bool is_constant;
	pure @safe {
		nothrow {
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
			string mangle() const {
				assert(false);
			}
		}
		string c_field(string lcode, string rhs, out TypeBase ty) const {
			assert(false);
		}
		string c_cast(const(TypeBase) target, string code) const {
			enforce(typeid_equals(typeid(target), typeid(this)), new CastError(this, target));
			return code;
		}
	}
}

class AnyType : TypeBase { }

class ParticleHandle : TypeBase {
override :
	string c_type() const { return "size_t"; }
	string d_type() const { return "size_t"; }
	TypeBase dup() const { return new ParticleHandle; }
	string str() const { return "ParticleHandle"; }
	bool opEquals(const(TypeBase) o) const {
		return o.type_match!ParticleHandle;
	}
	string c_cast(const(TypeBase) target, string code) const {
		enforce(target.type_match!ParticleHandle, new CastError(this, target));
		return code;
	}
	string mangle() const {
		return "P";
	}
}

class TextureType : TypeBase {
	const TexturePack parent;
	string subname;
	this(const(TexturePack) p, string n) {
		parent = p;
		subname = n;
	}
	this() {
		parent = null;
		subname = null;
	}
override :
	string c_field(string lcode, string rhs, out TypeBase ty) const {
		if (parent !is null) {
			auto r = parent.byname[subname];
			switch(rhs) {
			case 
			}
		}
	}
}

class Type(T: TexturePack) : TypeBase {
	const TexturePack instance;
	this(const(TexturePack) i) {
		instance = i;
	}
	this() {
		instance = null;
	}
override :
	string c_cast(const(TypeBase) target, string code) const {
		auto x = cast(typeof(this))target;
		if (x !is null)
			return code;
		assert(false);
	}
	string str() const {
		return "TexturePack";
	}
	TypeBase dup() const {
		return new Type!TexturePack(null);
	}
	string c_type() const { return "int"; }
	string mangle() const {
		return "TP";
	}
	string c_field(string lcode, string rhs, out TypeBase ty) const {
		if (instance !is null)
			ty = new TextureType(instance);
		else
			ty = new TextureType;
		return "get_sub_texture_by_name("~lcode~",\""~rhs~"\")";
	}
}

final class Type(T) : TypeBase
    if (!isPOD!T && is(typeof(T.init.name))) {
override :
	string c_cast(const(TypeBase) target, string code) const {
		auto x = cast(const(Type!T))target;
		assert(x !is null);
		return code;
	}
	string str() const {
		return T.stringof;
	}
	TypeBase dup() const {
		return new Type!T;
	}
	string c_type() const { return "int"; }
	bool opEquals(const(TypeBase) o) const {
		auto st = cast(const(Type!T))o;
		return (st !is null);
	}
	string c_copy(string src, string dst) const { assert(false); }
	string mangle() const {
		return T.stringof;
	}
}

class NamedType(T) : TypeBase {
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
			if (target.type_match!ParticleHandle)
				return "(size_t)("~code~"->__p)";
		}
		auto x = cast(const(NamedType!T))target;
		assert(x !is null);
		assert(x.name == name, "Type name mismatch, "~x.name~" != "~name);
		return code;
	}
	string str() const {
		assert(name !is null);
		return  T.stringof~" "~name;
	}
	TypeBase dup() const {
		return new NamedType!T(instance);
	}
	string c_type() const {
		static if (is(T == Particle))
			return "struct "~name~" *";
		else static if (is(T == Event))
			return "struct event_"~name;
		else static if (is(T == Vertex))
			return "struct vertex_"~name;
		else
			static assert(false);
	}
	bool opEquals(const(TypeBase) o) const {
		auto st = cast(const(NamedType!T))o;
		if (st is null)
			return false;
		return name == st.name;
	}
	string c_copy(string src, string dst) const { assert(false); }
	string c_field(string lcode, string rhs, out TypeBase ty) const {
		static if (is(T == Particle)) {
			auto d = cast(const(Var))instance.sym.lookup_checked(rhs);
			assert(d !is null, rhs~" field in "~name~" is not a variable");
			ty = d.ty.dup;
			return lcode~"->"~rhs;
		} else static if (is(T == Vertex)) {
			auto d = rhs in instance.map;
			assert(d !is null, rhs~" field doesn't exist in vertex "~name);
			ty = instance.map[rhs].ty.dup;
			return lcode~"."~rhs;
		} else
			assert(false);
	}
	string mangle() const {
		return T.stringof~name;
	}
}

class RangeBase : TypeBase { }

class RangeType(T, int dim=1) : RangeBase
  if (dim == 1 || is(T == float)) {
override :
	int dimension() const { return dim; }
	string str() const { return "Range"; }
	TypeBase dup() const { return new RangeType!(T, dim); }
	string c_type() const {
		import std.conv : to;
		static if (dim > 1)
			return "struct range"~to!string(dim);
		else static if (is(T == int))
			return "struct rangei";
		else
			return "struct rangef";
	}
	bool opEquals(const(TypeBase) t) const {
		auto rt = cast(typeof(this))t;
		if (rt is null)
			return false;
		return true;
	}
}

class Type(T) : TypeBase
    if (isPOD!T) {
	T constant_result;
override :
	string c_cast(const(TypeBase) target, string code) const {
		static if (!is(T == bool))
			if (target.type_match!(Type!float))
				return code;
		enforce(target.type_match!(Type!T), new CastError(this, target));
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
	string mangle() const {
		return T.stringof;
	}
}

class Type(T, int dim) : TypeBase
    if (is(T == float) && dim > 1) {
	T[dim] constant_result;
	static int field_name_to_index(char n) {
		switch(n) {
		case 'x':
			return 0;
		case 'y':
			return 1;
		case 'z':
			return 2;
		case 'w':
			return 3;
		default:
			assert(false);
		}
	}
override :
	int dimension() const {
		return dim;
	}
	string str() const {
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
	string c_field(string lcode, string rhs, out TypeBase type) const {
		if (rhs.length == 1) {
			type = new Type!float;
			return lcode~"."~rhs;
		}
		type = new_vec_type!float(cast(int)rhs.length);
		auto res = "({"; //We are using the gcc extension
		res ~= c_type~" __tmp = "~lcode~";\n";
		res ~= "("~type.c_type~"){";
		foreach(i, x; rhs) {
			int index = field_name_to_index(x);
			if (i != 0)
				res ~=",";
			res ~= "__tmp."~x;
		}
		res ~= "};\n})";
		return res;
	}
	TypeBase dup() const {
		return new Type!(T, dim);
	}
	bool opEquals(const(TypeBase) o) const {
		return o.type_match!(Type!(T, dim));
	}
	string mangle() const {
		return "v"~to!string(dim);
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

TypeBase new_vec_type(T)(int dim) {
	if (dim == 1)
		return new Type!T;
	switch(dim) {
		foreach(i; Iota!(2, 5)) {
			case i:
				return new Type!(T, i); //Vector must be float
		}
		default:
		assert(0);
	}
}
TypeBase new_rng_type(T)(int dim) {
	if (dim == 1)
		return new RangeType!T;
	switch(dim) {
		foreach(i; Iota!(2, 5)) {
			case i:
				return new RangeType!(T, i); //Vector must be float
		}
		default:
		assert(0);
	}
}
