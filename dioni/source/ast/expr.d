module ast.expr;
import ast.symbols, ast.decl;
import std.conv,
       std.range,
       std.typecons,
       std.traits,
       std.format;
import dioni.utils;
interface Expr {
	pure TypeBase gen_type(Symbols s);
	@property @nogc pure nothrow const(TypeBase) ty();
	@property pure nothrow string str();
	string c_code(Symbols s);
}

interface LValue : Expr {
	@property final bool is_lvalue() {
		return true;
	}
}

TypeBase type_matching(T...)(const(TypeBase)[] ity) {
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

template GetTy() {
	private TypeBase _ty;
	override pure TypeBase gen_type(Symbols s) {
		if (_ty !is null)
			return _ty.dup;
		_ty = _gen_type(s);
		return _ty.dup;
	}
	override @property nothrow pure const(TypeBase) ty() {
		assert(_ty !is null);
		return _ty;
	}
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
}
class Type(T, int dim) : TypeBase {
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
		static if (dim == 1)
			return T.stringof;
		else {
			import std.format;
			static assert(is(T == float));
			try {
				return format("struct vec%s", dim);
			} catch(Exception) {
				assert(false);
			}
		}
	}
	override TypeBase dup() const {
		return new Type!(T, dim);
	}
}
class ArrayType(ElemType) : TypeBase if (is(ElemType : TypeBase)) {
	override int dimension() const {
		static if (is(ElemType == Type!(T, dim), T, int dim))
			return dim;
		else
			static assert(0);
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
class BinOP : Expr {
	Expr lhs, rhs;
	string op;
	this(Expr xlhs, string xop, Expr xrhs) {
		lhs = xlhs;
		rhs = xrhs;
		op = xop;
	}
	override @property pure nothrow string str() {
		return "<" ~ lhs.str ~ op ~ rhs.str ~ ">";
	}
	override string c_code(Symbols s) {
		assert(ty !is null);
		if (ty.dimension != 1) {
			string suffix = "";
			final switch(op) {
			case "+":
				suffix = "add";
				break;
			case "-":
				suffix = "sub";
				break;
			case "*":
				if (rhs.ty.dimension == 1)
					suffix = "muln1";
				else if (lhs.ty.dimension == 1)
					suffix = "mul1n";
				else
					suffix = "mul";
				break;
			case "/":
				if (rhs.ty.dimension == 1)
					suffix = "div1";
				else
					suffix = "div";
				break;
			}
			return format("vec%s_%s(%s, %s)", ty.dimension, suffix,
				      lhs.c_code(s), rhs.c_code(s));
		}
		return format("(%s%s%s)", lhs.c_code(s), op, rhs.c_code(s));
	}
	pure TypeBase _gen_type(Symbols s) {
		lhs.gen_type(s);
		rhs.gen_type(s);
		auto ld = lhs.ty.dimension, rd = rhs.ty.dimension;
		if (ld > 1 || rd > 1) {
			int resd;
			switch(op) {
			case "+":
			case "-":
				assert(ld == rd);
				resd = ld;
				break;
			case "*":
				assert(ld == rd || ld == 1 || rd == 1);
				resd = (ld == 1) ? rd : ld;
				break;
			case "/":
				assert(ld == rd || rd == 1);
				resd = ld;
				break;
			default:
				assert(0);
			}
			switch(resd) {
				foreach(i; StaticRange!(2, 5)) {
					case i:
					return new Type!(float, i); //Vector must be float
				}
				default:
					assert(0);
			}
		}
		if (op == "+" || op == "-" || op == "*") {
			return type_matching!(
				TypePattern!(Type!(int, 1), Type!(int, 1), Type!(int, 1)),
				TypePattern!(Type!(float, 1), Type!(float, 1), Type!(float, 1)),
				TypePattern!(Type!(float, 1), Type!(int, 1), Type!(float, 1)),
				TypePattern!(Type!(float, 1), Type!(float, 1), Type!(float, 1)),
			)([lhs.ty, rhs.ty]);
		} else if (op == "/") {
			return type_matching!(
				TypePattern!(Type!(float, 1), Type!(int, 1), Type!(int, 1)),
				TypePattern!(Type!(float, 1), Type!(float, 1), Type!(float, 1)),
				TypePattern!(Type!(float, 1), Type!(int, 1), Type!(float, 1)),
				TypePattern!(Type!(float, 1), Type!(float, 1), Type!(float, 1)),
			)([lhs.ty, rhs.ty]);
		}
		assert(false);
	}
	mixin GetTy;
}

class UnOP : Expr {
	string op;
	Expr opr; ///Operand
	this(string xop, Expr xopr) {
		opr = xopr;
		op = xop;
	}
	T opCast(T: string)() {
		return op ~ to!string(opr);
	}
	pure TypeBase _gen_type(Symbols s) {
		return opr.gen_type(s);
	}
	override @property pure nothrow string str() {
		return op ~ opr.str;
	}
	override string c_code(Symbols s) {
		if (ty.dimension != 1) {
			assert(op == "-", "Unsupported '"~op~"' on vector");
			return format("vec%s_neg(%s)", ty.dimension, opr.c_code(s));
		}
		return format("(%s%s)", op, opr.c_code(s));
	}
	mixin GetTy;
}

class Var : LValue {
	string name;
	this(string xname) { name = xname; }
	pure TypeBase _gen_type(Symbols s) {
		auto d = s.lookup(name);
		assert(d !is null, "Undefined symbol "~name);
		auto vd = cast(VarDecl)d;
		assert(vd !is null, "Non-variable symbol "~name~" used as variable");
		return vd.ty.dup;
	}
	override @property pure nothrow string str() {
		return "Var(" ~ name ~ ")";
	}
	override string c_code(Symbols s) {
		auto d = s.lookup(name);
		assert(d !is null, "Undefined symbol "~name);
		auto vd = cast(VarDecl)d;
		assert(vd !is null, name~" is not a variable");
		if (vd.member)
			return format("(__current->%s)", name);
		else
			return format("(%s)", name);
	}
	mixin GetTy;
}

/*
class Index : LValue {
	LValue base;
	Expr index;
	this(LValue xbase, Expr xindex) {
		base = xbase;
		index = xindex;
	}
	override pure TypeBase gen_type() {
		auto x = base.ty.element_type;
		assert(x !is null);
		return x;
	}
	override @property pure nothrow string str() {
		return base.str ~ "[" ~ index.str ~ "]";
	}
	mixin GetTy;
}*/

class Field : LValue {
	string lhs, rhs;
	this(string xlhs, string xrhs) {
		lhs = xlhs;
		rhs = xrhs;
	}
	pure TypeBase _gen_type(Symbols s) {
		return null;
	}
	override @property pure nothrow string str() {
		return "<" ~ lhs ~ "." ~ rhs ~ ">";
	}
	override string c_code(Symbols s) {
		assert(false, "NIY");
	}
	mixin GetTy;
}

class Num : Expr {
	uint _type;
	union {
		float f;
		int i;
	}
	const(string) _str;
	this(float a) {
		_type = 0;
		f = a;
		_str = "Float(" ~ to!string(f) ~ ")";
	}
	this(int a) {
		_type = 1;
		i = a;
		_str = "Int(" ~ to!string(i) ~ ")";
	}
	@property pure nothrow string str() {
		return _str;
	}
	pure nothrow TypeBase _gen_type(Symbols s) {
		switch(_type) {
		case 0:
			return new Type!(float, 1);
		case 1:
			return new Type!(int, 1);
		default:
			assert(0);
		}
	}
	override string c_code(Symbols s) {
		final switch(_type) {
		case 0:
			return format("(%s)", f);
		case 1:
			return format("(%s)", i);
		}
	}
	mixin GetTy;
}

class Vec(int dim) : Expr if (dim >= 2) {
	Expr[dim] elem;
	const(string) _header;
	this(Expr[] xelem) {
		_header = "Vec"~to!string(dim)~"(";
		assert(xelem.length >= dim);
		foreach(i; StaticRange!(0, dim))
			elem[i] = xelem[i];
	}
	override @property pure nothrow string str() {
		auto res = _header.dup;
		foreach(i; StaticRange!(0, dim-1))
			res ~= elem[i].str ~ ", ";
		res ~= elem[dim-1].str ~ ")";
		return res;
	}
	pure nothrow TypeBase _gen_type(Symbols s) {
		return new Type!(float, dim);
	}
	override string c_code(Symbols s) {
		auto res = format("((struct vec%s){", dim);
		foreach(e; elem)
			res ~= e.c_code(s)~",";
		res ~= "})";
		return res;
	}
	mixin GetTy;
}

unittest {
	import std.stdio;
	writeln("Run ast.d unittest");
	auto lhs = new Num(1);
	auto rhs = new Num(1.0);
	auto s = new Symbols(null);
	auto bop = new BinOP(lhs, "+", rhs);
	bop.gen_type(s);
	writeln(typeid(new Type!(int, 1)));
	assert(typeid(bop.ty) == typeid(Type!(float, 1)));

	bop = new BinOP(lhs, "-", lhs);
	bop.gen_type(s);
	writeln(typeid(bop.ty));
	assert(typeid(bop.ty) == typeid(Type!(int, 1)));

	bop = new BinOP(lhs, "/", lhs);
	bop.gen_type(s);
	writeln(typeid(bop.ty));
	assert(typeid(bop.ty) == typeid(Type!(float, 1)));
}
