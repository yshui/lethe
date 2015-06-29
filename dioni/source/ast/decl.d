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
	@property void prefix(string p);
	@property void particle(string p);
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

pure nothrow string param_list(string particle) {
	string res;
	immutable string[] names = ["__current", "__next"];
	immutable string[] shared_names = ["__shared_current", "__shared_next"];
	foreach(i, n; names) {
		if (i != 0)
			res ~= ", ";
		res ~= "struct "~particle~"* "~n;
	}
	foreach(n; shared_names)
		res ~= ", struct "~particle~"_shared* "~n;
	return res;
}

class State : Decl {
	StateTransition[] st;
	Stmt[] entry;
	string name;
	private string _prefix, _particle;
	this(string xname, Stmt[] e, StateTransition[] xst) {
		name = xname;
		st = xst;
		entry = e;
	}
	override string symbol() {
		return name;
	}
	@property override string str() {
		auto res = "state("~name~"):\n";
		res ~= "entry: "~entry.str;
		foreach(ste; st)
			res ~= ste.str;
		return res;
	}
	override @property void prefix(string p) {
		_prefix = p;
	}
	override @property void particle(string p) {
		_particle = p;
	}
	override string c_code(Symbols p) {
		import std.format : format;
		auto res = format("static inline void %s_state_%s_entry(%s) {\n", _prefix, name, _particle.param_list);
		res ~= entry.c_code(p);
		res ~= "}";
		return res;
	}
}
enum StorageClass {
	Local,
	Particle,
	Shared
}
class VarDecl : Decl {
	const(TypeBase) ty;
	string name;
	StorageClass sc;
	pure this(const(TypeBase) xty, string xname, StorageClass xsc=StorageClass.Local) {
		name = xname;
		sc = xsc;
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
	override @property void prefix(string p) { }
	override @property void particle(string p) { }
}

class Ctor : Decl {
	Stmt[] stmt;
	private string _prefix, _particle;
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
		auto res = "static inline void "~_prefix~"_ctor("~_particle.param_list~") {\n";
		res ~= stmt.c_code(s)~"}";
		return res;
	}
	override @property void prefix(string p) {
		_prefix = p;
	}
	override @property void particle(string p) {
		_particle = p;
	}
}
