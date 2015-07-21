module ast.stmt;
import ast.expr, ast.symbols, ast.decl, ast.type;
import std.format;
interface Stmt {
	@property @safe nothrow pure string str() const;
	///changed: Whether this statement change a member of the particle
	@safe string c_code(Symbols s, ref bool changed) const;
}
class Assign : Stmt {
	LValue lhs;
	Expr rhs;
	static enum {
		Delayed,
		Aggregate,
		Assign
	};
	int type;
	@safe this(LValue xlhs, Expr xrhs, int xtype = Assign) {
		lhs = xlhs;
		rhs = xrhs;
		type = xtype;
	}
	string str() const {
		final switch(type) {
		case Delayed:
			if (rhs !is null)
				return lhs.str ~ " <- " ~ rhs.str ~ "\n";
			else
				return "Clear " ~ lhs.str ~ "\n";
		case Aggregate:
			return lhs.str ~ " << " ~ rhs.str ~ "\n";
		case Assign:
			return lhs.str ~ " = " ~ rhs.str ~ "\n";
		}
	}
	string c_code(Symbols s, ref bool changed) const {
		changed = false;
		final switch(type) {
		case Delayed:
			changed = true;
			return lhs.c_assign(rhs, s, true);
		case Assign:
			return lhs.c_assign(rhs, s, false);
		case Aggregate:
			return lhs.c_aggregate(rhs, s);
		}
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

	package string c_code(const(Stmt)[] ss, const(Symbols) p, out Shadows os, ref bool changed) {
		string res = "";
		Symbols c = new Symbols(p);
		changed = false;
		foreach(s; ss) {
			bool c2;
			res ~= s.c_code(c, c2);
			changed = changed || c2;
		}
		os = c.shadowed;
		return c.c_defs(StorageClass.Local)~res;
	}

	package string c_code(const(Stmt)[] ss, const(Symbols) p, ref bool changed) {
		Shadows _;
		return c_code(ss, p, _, changed);
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
	string c_code(Symbols s, ref bool changed) const {
		TypeBase ty;
		auto ccode = cond.c_code(s, ty);
		Shadows sha;
		assert(ty.dimension == 1, "if statement doesn't take vectors");
		auto res = "if ("~ccode~") {\n";
		res ~= _then.c_code(s, sha, changed)~"}\n";
		s.merge_shadowed(sha);
		bool changed2 = false;
		if (_else.length != 0) {
			res ~= "else {\n"~_else.c_code(s, sha, changed2)~"}\n";
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
	string c_code(Symbols s, ref bool changed) const {
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
	string c_code(Symbols sym, ref bool changed) const {
		Symbols x = new Symbols(sym);
		TypeBase rt;
		auto rcode = rng.c_code(sym, rt);
		auto rngt = cast(RangeType)rt;
		assert(rt.dimension == 1, "Can't use vectors for loop");
		assert(rngt.is_int, "Loop begin and end must have type 'int'");

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
		res ~= bdy.c_code(x, sha, changed);
		res ~= "}\n}\n";

		sym.merge_shadowed(sha);
		return res;
	}
}
