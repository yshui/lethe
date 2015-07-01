module ast.expr;
import ast.symbols, ast.decl;
import std.conv,
       std.range,
       std.typecons,
       std.traits,
       std.format;
import dioni.utils;
interface Expr {
	@property pure nothrow string str() const;
	string c_code(Symbols s, out TypeBase ty) const;
}

interface LValue : Expr {
	@property final bool is_lvalue() {
		return true;
	}
}

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
	override @property pure nothrow string str() const {
		return "<" ~ lhs.str ~ op ~ rhs.str ~ ">";
	}
	override string c_code(Symbols s, out TypeBase ty) const {
		TypeBase lty, rty;
		auto lcode = lhs.c_code(s, lty), rcode = rhs.c_code(s, rty);
		ty = gen_type(lty, rty, op);
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
				if (rty.dimension == 1)
					suffix = "muln1";
				else if (lty.dimension == 1)
					suffix = "mul1n";
				else
					suffix = "mul";
				break;
			case "/":
				if (rty.dimension == 1)
					suffix = "div1";
				else
					suffix = "div";
				break;
			}
			return format("vec%s_%s(%s, %s)", ty.dimension, suffix,
				      lcode, rcode);
		}
		return format("(%s%s%s)", lcode, op, rcode);
	}
	static pure TypeBase gen_type(const(TypeBase) lty, const(TypeBase) rty, string op) {
		auto ld = lty.dimension, rd = rty.dimension;
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
			)([lty, rty]);
		} else if (op == "/") {
			return type_matching!(
				TypePattern!(Type!(float, 1), Type!(int, 1), Type!(int, 1)),
				TypePattern!(Type!(float, 1), Type!(float, 1), Type!(float, 1)),
				TypePattern!(Type!(float, 1), Type!(int, 1), Type!(float, 1)),
				TypePattern!(Type!(float, 1), Type!(float, 1), Type!(float, 1)),
			)([lty, rty]);
		}
		assert(false);
	}
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
	override @property pure nothrow string str() const {
		return op ~ opr.str;
	}
	override string c_code(Symbols s, out TypeBase ty) const {
		auto ocode = opr.c_code(s, ty);
		if (ty.dimension != 1) {
			assert(op == "-", "Unsupported '"~op~"' on vector");
			return format("vec%s_neg(%s)", ty.dimension, ocode);
		}
		return format("(%s%s)", op, ocode);
	}
}

class Var : LValue {
	string name;
	this(string xname) { name = xname; }
	override @property pure nothrow string str() const {
		return "Var(" ~ name ~ ")";
	}
	override string c_code(Symbols s, out TypeBase ty) const {
		auto d = s.lookup(name);
		assert(d !is null, "Undefined symbol "~name);
		auto vd = cast(VarDecl)d;
		assert(vd !is null, name~" is not a variable");

		ty = vd.ty.dup;
		final switch(vd.sc) {
		case StorageClass.Particle:
			return format("(__current->%s)", name);
		case StorageClass.Shared:
			return format("(__shared_current->%s)", name);
		case StorageClass.Local:
			return format("(%s)", name);
		}
	}
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
	pure TypeBase _gen_type(Symbols s) const {
		return null;
	}
	override @property pure nothrow string str() const {
		return "<" ~ lhs ~ "." ~ rhs ~ ">";
	}
	override string c_code(Symbols s, out TypeBase ty) const {
		assert(false, "NIY");
	}
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
	@property pure nothrow string str() const {
		return _str;
	}
	override string c_code(Symbols s, out TypeBase ty) const {
		final switch(_type) {
		case 0:
			ty = new Type!(float, 1);
			return "("~text(f)~")";
		case 1:
			ty = new Type!(int, 1);
			return "("~text(i)~")";
		}
	}
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
	override @property pure nothrow string str() const {
		auto res = _header.dup;
		foreach(i; StaticRange!(0, dim-1))
			res ~= elem[i].str ~ ", ";
		res ~= elem[dim-1].str ~ ")";
		return res;
	}
	override string c_code(Symbols s, out TypeBase ty) const {
		ty = new Type!(float, dim);
		auto res = format("((struct vec%s){", dim);
		foreach(e; elem) {
			TypeBase tmpty;
			res ~= e.c_code(s, tmpty)~",";
			assert(typeid(tmpty) == typeid(Type!(int, 1)) ||
			       typeid(tmpty) == typeid(Type!(float, 1)));
		}
		res ~= "})";
		return res;
	}
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
