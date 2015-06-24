module ast.expr;
import std.conv,
       std.range,
       std.typecons,
       std.traits;
import dioni.utils;
interface Expr {
	@property pure nothrow string str();
	pure TypeBase gen_type();
	final string toString() {
		return str;
	}
	@property pure const(TypeBase) ty();
}

interface LValue : Expr {
	@property final bool is_lvalue() {
		return true;
	}
}

string type_matching(T...)(string[] name) {
	string res = "";
	foreach(tp; T) {
		static if (is(tp: TypePattern!M, M...)) {
			assert(name.length+1 == M.length);
			//Generate a "if"
			foreach(i, ty; M[1..$])
				//Check if "name"'s type can be casted to expected type
				res ~= "if(cast(" ~ ty.stringof ~ ")(" ~ name[i] ~ ".ty) !is null) {\n";
			res ~= "return new " ~ M[0].stringof ~ ";\n";
			foreach(i; 0..name.length)
				res ~= "}\n";
		} else
			static assert(false, tp.stringof);
	}
	res ~= "throw new Exception(\"No type match found";

	foreach(n; name)
		res ~= ", " ~ n ~ ":\" ~ to!string(typeid(" ~ n ~ ".ty)) ~ \"";
	
	res ~= "\");";

	return res;
}

template GetTy() {
	private TypeBase _ty;
	override @property pure const(TypeBase) ty() {
		if (_ty is null)
			_ty = gen_type();
		return _ty;
	}
}

class TypeBase {
	@property nothrow pure @nogc int dimension() const {
		return 0;
	}
	@property nothrow pure @nogc TypeBase element_type() const {
		return null;
	}
}
class Type(T, int dim) : TypeBase {
	override int dimension() const {
		return dim;
	}
}
class ArrayType(ElemType) : TypeBase if (is(ElemType : TypeBase)) {
	override int dimension() const {
		static if (is(ElemType == Type!(T, dim), T, int dim))
			return dim;
		else
			static assert(0);
	}
	override @property nothrow pure @nogc TypeBase element_type() const {
		return new ElemType();
	}
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
	override pure TypeBase gen_type() {
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
			mixin(type_matching!(
				TypePattern!(Type!(int, 1), Type!(int, 1), Type!(int, 1)),
				TypePattern!(Type!(float, 1), Type!(float, 1), Type!(float, 1)),
				TypePattern!(Type!(float, 1), Type!(int, 1), Type!(float, 1)),
				TypePattern!(Type!(float, 1), Type!(float, 1), Type!(float, 1)),
			)(["lhs", "rhs"]));
		} else if (op == "/") {
			mixin(type_matching!(
				TypePattern!(Type!(float, 1), Type!(int, 1), Type!(int, 1)),
				TypePattern!(Type!(float, 1), Type!(float, 1), Type!(float, 1)),
				TypePattern!(Type!(float, 1), Type!(int, 1), Type!(float, 1)),
				TypePattern!(Type!(float, 1), Type!(float, 1), Type!(float, 1)),
			)(["lhs", "rhs"]));
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
	override pure TypeBase gen_type() {
		return opr.gen_type();
	}
	override @property pure nothrow string str() {
		return op ~ opr.str;
	}
	mixin GetTy;
}

class Var : LValue {
	string name;
	this(string xname) { name = xname; }
	override pure TypeBase gen_type() {
		return new Type!(int, 1);
	}
	override @property pure nothrow string str() {
		return "Var(" ~ name ~ ")";
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
	override pure TypeBase gen_type() {
		return null;
	}
	override @property pure nothrow string str() {
		return "<" ~ lhs ~ "." ~ rhs ~ ">";
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
	override pure nothrow TypeBase gen_type() {
		switch(_type) {
		case 0:
			return new Type!(float, 1);
		case 1:
			return new Type!(int, 1);
		default:
			assert(0);
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
	override pure nothrow TypeBase gen_type() {
		return new Type!(float, dim);
	}
	mixin GetTy;
}
unittest {
	import std.stdio;
	writeln("Run ast.d unittest");
	auto lhs = new Num(1);
	auto rhs = new Num(1.0);
	auto bop = new BinOP(lhs, "+", rhs);
	assert(typeid(bop.ty) == typeid(Type!(float, 1)));

	bop = new BinOP(lhs, "-", lhs);
	assert(typeid(bop.ty) == typeid(Type!(int, 1)));

	bop = new BinOP(lhs, "/", lhs);
	assert(typeid(bop.ty) == typeid(Type!(float, 1)));
	writeln(type_matching!(
		TypePattern!(Type!(int, 1), Type!(int, 1), Type!(int, 1)),
		TypePattern!(Type!(float, 1), Type!(float, 1), Type!(float, 1)),
		TypePattern!(Type!(float, 1), Type!(int, 1), Type!(float, 1)),
		TypePattern!(Type!(float, 1), Type!(float, 1), Type!(float, 1)),
	)(["lhs", "rhs"]));
}
