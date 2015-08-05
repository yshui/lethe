module ast.stmt;
import ast.expr, ast.symbols, ast.decl, ast.type;
import std.format;
import std.exception : enforceEx;
import error;
private alias enforce = std.exception.enforceEx!CompileError;
interface Stmt {
	@property @safe nothrow pure string str() const;
	///changed: Whether this statement change a member of the particle
	@safe string c_code(Symbols s, ref bool changed, const(Decl) parent) const;
}
class Ret : Stmt {
	Expr val;
	@safe this(Expr v) {
		val = v;
	}
	string str() const {
		return "=> "~(val is null ? "void" : val.str);
	}
	string c_code(Symbols s, ref bool changed, const(Decl) parent) const {
		changed = false;
		TypeBase ty;
		auto fn = cast(const(Func))parent,
		     st = cast(const(State))parent,
		     ctor = cast(const(Ctor))parent;
		if (ctor !is null) {
			enforce(val is null, "Can't return value in ctor");
			return "return;";
		}

		auto code = val.c_code(s, ty);
		if (fn !is null)
			return "return "~ty.c_cast(fn.retty, code)~";\n";
		else if (st !is null){
			enforce(ty.type_match!(Type!State), "next state is not state");
			return "return "~code~";\n";
		} else
			assert(false, "Impossible parent");
	}
}
class Assign : Stmt {
	LValue lhs;
	Expr rhs;
	bool delayed;
	@safe this(LValue xlhs, Expr xrhs, bool d) {
		lhs = xlhs;
		rhs = xrhs;
		delayed = d;
	}
	string str() const {
		if (delayed)
			return lhs.str~" <- "~rhs.str~"\n";
		else
			return lhs.str ~ " = " ~ rhs.str ~ "\n";
	}
	string c_code(Symbols s, ref bool changed, const(Decl) parent) const {
		changed = delayed;
		return lhs.c_assign(rhs, s, delayed);
	}
}
class Clear : Stmt {
	LValue lhs;
	@safe this(LValue xlhs) {
		lhs = xlhs;
	}
	string str() const {
		return lhs.str()~"~\n";
	}
	string c_code(Symbols s, ref bool changed, const(Decl) parent) const {
		assert(false);
	}
}
class Aggregate : Stmt {
	LValue lhs;
	Expr[] items;
	@safe this(LValue xlhs, Expr[] x) {
		items = x;
		lhs = xlhs;
	}
	string str() const {
		auto res = lhs.str~" << {";
		foreach(i, x; items) {
			if (i!=0)
				res ~= ", ";
			res ~= x.str;
		}
		res ~= "}\n";
		return res;
	}
	string c_code(Symbols s, ref bool changed, const(Decl) parent) const {
		auto res = "";
		res ~= items.map!(x => lhs.c_aggregate(x, s)).join("");
		changed = false;
		return res;
	}
}
@safe {
	package pure nothrow string str(const(Stmt)[] ss) {
		string res = "";
		foreach(s; ss)
			res ~= s.str;
		if (res == "")
			res ~= "\n";
		return res;
	}

	package string c_code(const(Stmt)[] ss, const(Decl) parent, const(Symbols) p, out Shadows os, ref bool changed) {
		string res = "";
		Symbols c = new Symbols(p);
		changed = false;
		foreach(s; ss) {
			bool c2;
			res ~= s.c_code(c, c2, parent);
			changed = changed || c2;
		}
		os = c.shadowed;
		return c.c_defs(StorageClass.Local)~res;
	}

	package string c_code(const(Stmt)[] ss, const(Decl) parent, const(Symbols) p, ref bool changed) {
		Shadows _;
		return c_code(ss, parent, p, _, changed);
	}
}
class If : Stmt {
	Expr cond;
	Stmt[] _then, _else;
	@safe this(Expr xcond, Stmt[] t, Stmt[] e) {
		cond = xcond;
		_then = t;
		_else = e;
	}
	string str() const {
		auto res = "If(" ~ cond.str ~ ") Then {\n";
		res ~= _then.str;
		res ~= "} Else {\n";
		res ~= _else.str;
		res ~= "}\n";
		return res;
	}
	string c_code(Symbols s, ref bool changed, const(Decl) parent) const {
		TypeBase ty;
		auto ccode = cond.c_code(s, ty);
		Shadows sha;
		assert(ty.dimension == 1, "if statement doesn't take vectors");
		auto res = "if ("~ccode~") {\n";
		res ~= _then.c_code(parent, s, sha, changed)~"}\n";
		s.merge_shadowed(sha);
		bool changed2 = false;
		if (_else.length != 0) {
			res ~= "else {\n"~_else.c_code(parent, s, sha, changed2)~"}\n";
			s.merge_shadowed(sha);
		}
		changed = changed || changed2;
		return res;
	}
}
class Foreach : Stmt {
	VarVal var, agg;
	Stmt[] bdy;
	@safe this(VarVal xvar, VarVal xagg, Stmt[] b) {
		var = xvar;
		agg = xagg;
		bdy = b;
	}
	string str() const {
		auto res = "Foreach(" ~ var.str ~ " in " ~ agg.str ~ ") {\n";
		res ~= bdy.str;
		res ~= "}\n";
		return res;
	}
	string c_code(Symbols s, ref bool changed, const(Decl) parent) const {
		assert(false, "NIY");
	}
}
class Loop : Stmt {
	Range rng;
	VarVal var;
	Stmt[] bdy;
	@safe this(VarVal xvar, Range r, Stmt[] xbdy) {
		rng = r;
		var = xvar;
		bdy = xbdy;
	}
	string str() const {
		auto res = "Loop("~(var is null ? "_" : var.str)~"~"~rng.str~") {\n";
		res ~= bdy.str;
		res ~= "}\n";
		return res;
	}
	string c_code(Symbols sym, ref bool changed, const(Decl) parent) const {
		Symbols x = new Symbols(sym);
		TypeBase rt;
		auto rcode = rng.c_code(sym, rt);
		auto rngt = cast(RangeType!int)rt;
		assert(rngt !is null, "Loop range must be dimension 1, integer range");

		import std.conv : to;
		auto level = to!string(x.level);
		auto rname = "__rng_"~level;
		auto rvar = new Var(rt, null, rname, Protection.Const);
		x.insert(rvar);

		auto lname = var is null ? "__r_"~level : var.name;
		auto lvar = new Var(new Type!int, null, lname, Protection.Const);
		x.insert(lvar);

		auto res = "{\n";
		Shadows sha;
		res ~= x.c_defs(StorageClass.Local);
		res ~= rname~" = "~rcode~";\n";
		res ~= "for("~lname~" = "~rname~".a; "~lname~" < "~rname~".o; "~lname~"++) {\n";
		res ~= bdy.c_code(parent, x, sha, changed);
		res ~= "}\n}\n";

		sym.merge_shadowed(sha);
		return res;
	}
}
