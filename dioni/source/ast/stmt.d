module ast.stmt;
import ast.expr;
interface Stmt {
	@property nothrow pure string str();
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
	string str() {
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
}
package nothrow pure string str_stmt_block(Stmt[] ss) {
	string res = "";
	foreach(s; ss)
		res ~= s.str;
	if (res == "")
		res ~= "\n";
	return res;
}
class If : Stmt {
	Expr cond;
	Stmt[] _then, _else;
	this(Expr xcond, Stmt[] t, Stmt[] e) {
		cond = xcond;
		_then = t;
		_else = e;
	}
	string str() {
		auto res = "If(" ~ cond.str ~ ") Then {\n";
		res ~= str_stmt_block(_then);
		res ~= "} Else {\n";
		res ~= str_stmt_block(_else);
		res ~= "}\n";
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
	string str() {
		auto res = "Foreach(" ~ var.str ~ " in " ~ agg.str ~ ") {\n";
		res ~= str_stmt_block(bdy);
		res ~= "}\n";
		return res;
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
	string str() {
		auto res = "Loop(" ~ (var is null ? "_" : var.str) ~ " from " ~ s.str ~ " to " ~ t.str ~ ") {\n";
		res ~= str_stmt_block(bdy);
		res ~= "}\n";
		return res;
	}
}
