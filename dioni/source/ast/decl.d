module ast.decl;
import ast.expr,
       ast.stmt,
       ast.symbols;

interface Decl {
	@property nothrow pure string symbol();
	@property nothrow pure string str();
	final string toString() {
		return str;
	}
	string c_code(Symbols s);
	void set_prefix(string p);
}

class EventParameter {
	Var var;
	Expr expr;
	static enum {
		Match,
		Assign,
		Ignore
	}
	int type;
	this(Var v) {
		assert(v !is null);
		type = Assign;
		var = v;
	}
	this(Expr e) {
		assert(e !is null);
		type = Match;
		expr = e;
	}
	this() {
		type = Ignore;
	}
}

package pure nothrow string str_event_parameters(EventParameter[] ep) {
	auto res = "";
	foreach(i, e; ep) {
		final switch(e.type) {
		case EventParameter.Match:
			res ~= "=" ~ e.expr.str;
			break;
		case EventParameter.Assign:
			res ~= "~" ~ e.var.str;
			break;
		case EventParameter.Ignore:
			res ~= "_";
			break;
		}
		if (i+1 != ep.length)
			res ~= ", ";
	}
	return res;
}

class Event {
	string name;
	EventParameter[] ep;
	this(string xname, EventParameter[] xep) {
		ep = xep;
		name = xname;
	}
	pure nothrow string str() {
		return name ~ "(" ~ str_event_parameters(ep) ~ ")";
	}
}

class StateTransition {
	Event e;
	string next;
	Stmt[] s;
	this(Event xe, Stmt[] xs, string xnext) {
		e = xe;
		s = xs;
		next = xnext;
	}
	pure nothrow string str() {
		auto res = "On event " ~ e.str ~ " do:\n";
		res ~= s.str;
		res ~= "=> " ~ next ~ "\n";
		return res;
	}
}

class State : Decl {
	StateTransition[] st;
	Stmt[] entry;
	string name;
	string prefix;
	this(string xname, Stmt[] e, StateTransition[] xst) {
		name = xname;
		st = xst;
		entry = e;
	}
	override string symbol() {
		return name;
	}
	@property override string str() {
		auto res = "state(" ~ name ~ "):\n";
		res ~= "entry: " ~ entry.str;
		foreach(ste; st)
			res ~= ste.str;
		return res;
	}
	override void set_prefix(string p) {
		prefix = p;
	}
	override string c_code(Symbols p) {
		import std.format : format;
		auto res = format("static inline void %s_state_%s_entry(struct %s *__next) {\n", prefix, name, prefix);
		res ~= entry.c_code(p);
		res ~= "}";
		return res;
	}
}

class VarDecl : Decl {
	const(TypeBase) ty;
	string name;
	bool member;
	pure this(const(TypeBase) xty, string xname, bool xmember=false) {
		name = xname;
		member = xmember;
		ty = xty;
	}
	override string str() {
		return name ~ ":" ~ ty.str ~ "\n";
	}
	override string symbol() {
		return name;
	}
	override string c_code(Symbols s) {
		return "";
	}
	override void set_prefix(string p) { }
}

class Ctor : Decl {
	Stmt[] stmt;
	string prefix;
	this(Stmt[] x) {
		stmt = x;
	}
	override string str() {
		return "Ctor: " ~ stmt.str;
	}
	override string symbol() {
		return "this";
	}
	override string c_code(Symbols s) {
		auto res = "void "~prefix~"_ctor() {\n";
		res ~= stmt.c_code(s)~"}";
		return res;
	}
	override void set_prefix(string p) {
		prefix = p;
	}
}
