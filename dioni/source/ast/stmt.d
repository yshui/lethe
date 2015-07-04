module ast.stmt;
import ast.expr, ast.symbols, ast.decl, ast.type;
import std.format;
interface Stmt {
	@property nothrow pure string str() const;
	string c_code(Symbols s) const;
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
	this(LValue xlhs, Expr xrhs, int xtype = Assign) {
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
	string c_code(Symbols s) const {
		assert(type != Aggregate);
		TypeBase ty;
		auto rcode = rhs.c_code(s, ty);
		auto v = cast(Var)lhs;
		if (v !is null) {
			auto d = s.lookup(v.name);
			VarDecl vd;
			if (d is null) {
				//New variable
				vd = new VarDecl(ty, v.name);
				s.insert(vd);
			} else {
				vd = cast(VarDecl)d;
				assert(vd !is null, "Assigning to non variable");
				assert(typeid(ty) == typeid(vd.ty), "Type mismatch: "~vd.name~":"~typeid(vd.ty).toString~"!="~typeid(ty).toString);
				assert(vd.prot != Protection.Const, "Writing to readonly variable '"~v.name~"'");
			}
			if (type == Delayed) {
				assert(vd.sc != StorageClass.Local, "Delayed assign can't be used with local variable");
				return vd.c_access(true)~" = "~rcode~";\n";
			} else {
				assert(vd.sc == StorageClass.Local, "Direct assign can only be used with local variable");
				return format("%s = %s;\n", v.name, rcode);
			}
		}
		assert (false, "Not implemented assign to field");
	}
}
package nothrow pure string str(const(Stmt)[] ss) {
	string res = "";
	foreach(s; ss)
		res ~= s.str;
	if (res == "")
		res ~= "\n";
	return res;
}

package string c_code(const(Stmt)[] ss, const(Symbols) p) {
	string res = "";
	Symbols c = new Symbols(p);
	foreach(s; ss)
		res ~= s.c_code(c);
	return c.c_defs(StorageClass.Local)~res;
}
class If : Stmt {
	Expr cond;
	Stmt[] _then, _else;
	this(Expr xcond, Stmt[] t, Stmt[] e) {
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
	override string c_code(Symbols s) const {
		TypeBase ty;
		auto ccode = cond.c_code(s, ty);
		assert(ty.dimension == 1, "if statement doesn't take vectors");
		auto res = "if ("~ccode~") {\n";
		res ~= _then.c_code(s)~"}\n";
		if (_else.length != 0)
			res ~= "else {\n"~_else.c_code(s)~"}\n";
		return res;
	}
}
class Foreach : Stmt {
	Var var, agg;
	Stmt[] bdy;
	this(Var xvar, Var xagg, Stmt[] b) {
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
	override string c_code(Symbols s) const {
		assert(false, "NIY");
	}
}
class Loop : Stmt {
	Expr s, t;
	Var var;
	Stmt[] bdy;
	this(Var xvar, Expr xs, Expr xt, Stmt[] xbdy) {
		s = xs;
		t = xt;
		var = xvar;
		bdy = xbdy;
	}
	string str() const {
		auto res = "Loop(" ~ (var is null ? "_" : var.str) ~ " from " ~ s.str ~ " to " ~ t.str ~ ") {\n";
		res ~= bdy.str;
		res ~= "}\n";
		return res;
	}
	override string c_code(Symbols sym) const {
		Symbols x = new Symbols(sym);
		TypeBase sty, tty;
		auto scode = s.c_code(sym, sty), tcode = t.c_code(sym, tty);
		assert(sty.dimension == 1 && tty.dimension == 1, "Can't use vectors for loop");
		assert(typeid(sty) == typeid(tty), "Loop begin and end have different type");
		assert(typeid(sty) == typeid(Type!int), "Loop begin and end must have type 'int'");

		import std.conv : to;
		auto level = to!string(x.level);
		auto sname = "__s_"~level, tname = "__t_"~level;
		auto svar = new VarDecl(sty, sname, Protection.Const),
		     tvar = new VarDecl(tty, tname, Protection.Const);
		x.insert(svar);
		x.insert(tvar);

		auto lname = var is null ? "__r_"~level : var.name;
		auto lvar = new VarDecl(sty, lname, Protection.Const);
		x.insert(lvar);

		auto res = "{\n";
		res ~= x.c_defs(StorageClass.Local);
		res ~= sname~" = "~scode~";\n";
		res ~= tname~" = "~tcode~";\n";
		res ~= "for("~lname~" = "~sname~"; "~lname~" < "~tname~"; "~lname~"++) {\n";
		res ~= bdy.c_code(x);
		res ~= "}\n}\n";
		return res;
	}
}
