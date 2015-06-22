module ast.stmt;
interface Stmt {
	@property pure nothrow string str();
	final string toString() {
		return str;
	}
}
class Assign : Stmt {
	LValue lhs;
	Expr rhs;
	this(LValue xlhs, Expr xrhs) {
		lhs = xlhs;
		rhs = xrhs;
	}
	string str() {
		return lhs ~ " = " ~ rhs ~ "\n";
	}
}
private nothrow pure string str_stmt_block(Stmt[] ss) {
	string res = "";
	foreach(s; ss)
		res ~= s.str;
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
		auto res = "Foreach(" ~ var ~ " in " ~ agg.str ~ ") {\n";
		res ~= str_stmt_block(bdy);
		res ~= "}\n";
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
}
