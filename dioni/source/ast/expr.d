module ast.expr;
import ast.symbols, ast.decl, ast.type, ast.stmt, ast.aggregator;
import std.conv,
       std.range,
       std.typecons,
       std.traits,
       std.format,
       std.exception;
import dioni.utils;
interface Expr {
	@safe nothrow {
		pure @property string str() const;
		string c_code(const(Symbols) s, out TypeBase ty) const;
	}
}

interface LValue : Expr {
	@safe {
		string c_assign(const(Expr) rhs, Symbols s, bool delayed) const;
		string c_aggregate(const(Expr) rhs, const(Symbols) s) const;
		string c_clear(const(Symbols) s) const;
	}
}

class Range : Expr {
	Expr a, o;
	this(Expr x, Expr y) {
		a = x;
		o = y;
	}
	override {
		string str() const {
			return a.str~".."~o.str;
		}
		string c_code(const(Symbols) s, out TypeBase ty) const {
			TypeBase at, ot;
			auto ac = a.c_code(s, at), oc = o.c_code(s, ot);
			assert(at.dimension == ot.dimension);
			if (at.dimension > 1) {
				ty = new RangeType(at.dimension, false);
				return "((struct range"~to!string(at.dimension)~
				       "){"~ac~", "~oc~"})";
			}
			if (at.type_match!(Type!int) &&
			    ot.type_match!(Type!int)) {
				ty = new RangeType(1, true);
				return "((struct rangei){"~ac~", "~oc~"})";
			}
			ty = new RangeType(1, false);
			return "((struct rangef){"~ac~", "~oc~"})";
		}
	}
}

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
	override string c_code(const(Symbols) s, out TypeBase ty) const {
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
			return assumeWontThrow(format("vec%s_%s(%s, %s)", ty.dimension, suffix,
					       lcode, rcode));
		}
		return assumeWontThrow(format("(%s%s%s)", lcode, op, rcode));
	}
	static pure @safe nothrow TypeBase
	gen_type(const(TypeBase) lty, const(TypeBase) rty, string op) {
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
			return type_calc!(
					TypePattern!(Type!int,   Type!int,   Type!int),
					TypePattern!(Type!float, Type!float, Type!float),
					TypePattern!(Type!float, Type!int,   Type!float),
					TypePattern!(Type!float, Type!float, Type!float),
					)([lty, rty]);
		} else if (op == "/") {
			return type_calc!(
					TypePattern!(Type!float, Type!int,   Type!int),
					TypePattern!(Type!float, Type!float, Type!float),
					TypePattern!(Type!float, Type!int,   Type!float),
					TypePattern!(Type!float, Type!float, Type!float),
					)([lty, rty]);
		}
		assert(false);
	}
}

class BoolOP : Expr {
	string op;
	Expr lhs, rhs;
	@safe nothrow pure this(Expr a, string o, Expr b) {
		lhs = a;
		rhs = b;
		op = o;
	}
override :
	string str() const {
		return lhs.str~op~rhs.str;
	}
	string c_code(const(Symbols) s, out TypeBase ty) const {
		TypeBase lt, rt;
		auto lc = lhs.c_code(s, lt), rc = rhs.c_code(s, rt);
		assert(lt.type_match!(Type!bool));
		assert(rt.type_match!(Type!bool));
		ty = new Type!bool;
		return "("~lc~op~rc~")";
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
	override string c_code(const(Symbols) s, out TypeBase ty) const {
		auto ocode = opr.c_code(s, ty);
		if (ty.dimension != 1) {
			assert(op == "-", "Unsupported '"~op~"' on vector");
			return assumeWontThrow(format("vec%s_neg(%s)", ty.dimension, ocode));
		}
		return assumeWontThrow(format("(%s%s)", op, ocode));
	}
}

class Var : LValue {
	string name;
	this(string xname) { name = xname; }
override :
	string str() const {
		return "Var(" ~ name ~ ")";
	}
	string c_code(const(Symbols) s, out TypeBase ty) const {
		auto d = s.lookup(name);
		assert(d !is null, "Undefined symbol "~name);
		auto vd = cast(const(VarDecl))d;
		auto sd = cast(const(State))d;

		if (vd !is null) {
			ty = vd.ty.dup;
			return vd.c_access;
		} else if (sd !is null) {
			ty = new StateType(sd.symbol);
			return sd.c_access;
		} else
			assert(false, name~" is not a variable or state name");
	}
	string c_assign(const(Expr) rhs, Symbols s, bool delayed) const {
		import std.typecons : Rebindable;
		auto d = s.lookup(name);
		TypeBase rty;
		auto rcode = rhs.c_code(s, rty);
		Rebindable!(const(VarDecl)) vd;
		if (d is null) {
			assert(rty.dimension > 1 ||
			       rty.type_match!(Type!int) ||
			       rty.type_match!(Type!float) ||
			       rty.type_match!ParticleHandle ||
			       rty.type_match!StateType ||
			       rty.type_match!AnonymousType, typeid(rty).toString);
			vd = new VarDecl(rty, name);
			s.insert(vd);
			if (rty.type_match!(AnonymousType))
				return "";
		} else {
			vd = cast(const(VarDecl))d;
			assert(vd !is null, name~" is not a variable");
		}

		auto agg = cast(const(Aggregator))vd.ty;
		if (agg !is null)
			return agg.c_assign(vd, rhs, s, delayed);
		if (vd.ty.type_match!AnonymousType) {
			if (rty.type_match!AnonymousType)
				return "";
			auto nvd = new VarDecl(rty, vd.name);
			s.shadow(nvd);
			vd = nvd;
		} else
			assert(type_compatible(rty, vd.ty), typeid(rty).toString~" "~typeid(vd.ty).toString);
		assert(vd.prot != Protection.Const, "Writing to const variable '"~
		       name~"'");
		if (vd.sc == StorageClass.Particle)
			assert(delayed, "Assignment to particle member should use <- ");
		return vd.c_access(true)~" = "~rcode~";\n";
	}
	string c_aggregate(const(Expr) rhs, const(Symbols) s) const { assert(false); }
	string c_clear(const(Symbols) s) const { assert(false); }
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
	override @property pure nothrow string str() const {
		return "<" ~ lhs ~ "." ~ rhs ~ ">";
	}
	override string c_code(const(Symbols) s, out TypeBase ty) const {
		//Lookup left
		auto d = cast(const(VarDecl))s.lookup_checked(lhs);
		assert(d !is null, lhs~" is not a variable");
		auto p = cast(const(UDType))d.ty;
		assert(p !is null, lhs~" is not a particle, can't use it in field expr");
		auto d2 = cast(const(VarDecl))p.p.sym.lookup_checked(rhs);
		assert(d2 !is null, rhs~" field in "~lhs~" is not a variable");
		ty = d2.ty.dup;
		return lhs~"->"~rhs;
	}
	string c_assign(const(Expr) rhs, Symbols s, bool delayed) const { assert(false); }
	string c_aggregate(const(Expr) rhs, const(Symbols) s) const { assert(false); }
	string c_clear(const(Symbols) s) const { assert(false); }
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
	override string c_code(const(Symbols) s, out TypeBase ty) const {
		final switch(_type) {
		case 0:
			ty = new Type!float;
			return assumeWontThrow(format("(%s)", f));
		case 1:
			ty = new Type!int;
			return assumeWontThrow(format("(%s)", i));
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
	override string c_code(const(Symbols) s, out TypeBase ty) const {
		ty = new Type!(float, dim);
		auto res = assumeWontThrow(format("((struct vec%s){", dim));
		foreach(e; elem) {
			TypeBase tmpty;
			res ~= e.c_code(s, tmpty)~",";
			assert(tmpty.type_match!(Type!int) ||
			       tmpty.type_match!(Type!float));
		}
		res ~= "})";
		return res;
	}
}

class QMark : Expr {
	override string str() const {
		return "?";
	}
	override string c_code(const(Symbols) s, out TypeBase ty) const {
		ty = new AnonymousType;
		return "";
	}
}

pure nothrow @safe
string op_to_name(string op) {
	final switch(op) {
	case "==": return "eq";
	case "<=": return "le";
	case ">=": return "ge";
	case "!=": return "ne";
	case "<": return "lt";
	case ">": return "gt";
	}
}

pure nothrow @safe
string c_match(string[2] code, const(TypeBase)[2] ty, string op) {
	if (op == "~") {
		auto rngty = cast(const(RangeType))ty[1];
		auto tagty = cast(const(TagType))ty[1];
		if(rngty !is null) {
			assert(ty[0].dimension == ty[1].dimension);
			if (ty[1].dimension > 1)
				return "vector_in_range"~to!string(ty[1].dimension)~
				       "("~code[0]~", "~code[1]~")";
			assert(type_compatible(ty[0], new Type!float));
			if (rngty.is_int)
				return "number_in_rangei("~code[0]~", "~code[1]~")";
			else
				return "number_in_rangef("~code[0]~", "~code[1]~")";
		} else if (tagty !is null) {
			if (ty[0].type_match!ParticleHandle)
				return "particle_has_tag("~code[0]~", "~code[1]~")";
			auto udt = cast(const(UDType))ty[0];
			assert(udt !is null);
			assert(udt.name is null || udt.p !is null);
			return "has_tag("~code[0]~"->__tags, "~code[1]~")";
		}
	}
	if (ty[0].dimension > 1) {
		assert(ty[0].dimension == ty[1].dimension);
		return "vec"~to!string(ty[1].dimension)~"_"~op_to_name(op)~"("~code[0]~", "~code[1]~")";
	}
	assert(type_compatible(ty[0], new Type!float));
	return "("~code[0]~op~code[1]~")";
}

class Cmp : Expr {
	Expr lhs, rhs;
	string op;
	this(Expr xl, string xo, Expr xr) {
		lhs = xl;
		op = xo;
		rhs = xr;
	}
	override {
		string str() const {
			return lhs.str~op~rhs.str;
		}
		override string c_code(const(Symbols) s, out TypeBase ty) const {
			ty = new Type!bool;
			TypeBase lt, rt;
			auto lc = lhs.c_code(s, lt), rc = rhs.c_code(s, rt);
			return c_match([lc, rc], [lt, rt], op);
		}
	}
}

class NewExpr : Expr, Stmt {
	string name;
	Expr[] param;
	this(string n, Expr[] p) {
		name = n;
		param = p;
	}
	override string str() const {
		return "New";
	}
	override string c_code(const(Symbols) s, out TypeBase ty) const {
		auto d = s.lookup_checked(name);
		auto pd = cast(const(Particle))d,
		     sd = cast(const(State))d,
		     ed = cast(const(Event))d;
		if (pd !is null) {
			auto ctor = pd.ctor;
			if (ctor is null) {
				assert(param.length == 0, "ctor of "~name~" doesn't take any parameter");
				return "(new_particle_"~name~"())";
			} else {
				auto res = "(new_particle_"~name~"(";
				foreach(i, p; param) {
					if (i != 0)
						res ~= ", ";
					TypeBase pty;
					auto pcode = p.c_code(s, pty);
					assert(type_compatible(pty, ctor.param_def[i].ty),
					       "Type mismatch with ctor");
					res ~= pcode;
				}
				res ~= "))";
				ty = new ParticleHandle;
				return res;
			}
		} else if (sd !is null) {
			ty = new StateType(sd.name);
			return "(PARTICLE_"~sd.parent.name~"_STATE_"~sd.name~")";
		} else if (ed !is null) {
			assert(param.length == ed.member.length,
			       "Event "~ed.name~" has "~to!string(ed.member.length)~
			       "members, but "~to!string(param.length)~" are given");
			auto res = "((struct event_"~ed.name~"){";
			foreach(i, p; param) {
				if (i != 0)
					res ~= ", ";
				TypeBase pty;
				auto pcode = p.c_code(s, pty);
				assert(pty.opEquals(ed.member[i]), "Event member type mismatch");
				res ~= pcode;
			}
			res ~= "})";
			ty = new EventType(ed.name);
			return res;
		} else
			assert(false);
	}
	override string c_code(Symbols s) const {
		TypeBase ty;
		auto code = c_code(s, ty);
		assert(typeid(ty) == typeid(ParticleHandle),
		       "Creating "~name~" without assigning it makes no sense.");
		return code~";\n";
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
	assert(typeid(bop.ty) == typeid(Type!float));

	bop = new BinOP(lhs, "-", lhs);
	bop.gen_type(s);
	writeln(typeid(bop.ty));
	assert(typeid(bop.ty) == typeid(Type!int));

	bop = new BinOP(lhs, "/", lhs);
	bop.gen_type(s);
	writeln(typeid(bop.ty));
	assert(typeid(bop.ty) == typeid(Type!float));
}
