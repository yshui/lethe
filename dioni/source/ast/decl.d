module ast.decl;
import ast.expr,
       ast.stmt,
       ast.symbols;

interface Decl {
	@property nothrow pure string symbol() const;
	@property nothrow pure string str() const;
	final string toString() const {
		return str;
	}
	string c_code(string particle, string prefix, Symbols s) const;
	pure nothrow Decl combine(const(Decl) o) const;
}

class EventParameter {
	Var var;
	Expr expr;
	this(Var v, Expr e) {
		var = v;
		expr = e;
	}
	string str() {
		string res;
		if (var is null)
			res = "_";
		else
			res = var.name;
		res ~= "~";
		if (expr is null)
			res ~= "_";
		else
			res ~= expr.str;
		return res;
	}
}

package pure nothrow string str_event_parameters(EventParameter[] ep) {
	auto res = "";
	foreach(i, e; ep) {
		if (i)
			res ~= ", ";
		res ~= e.str;
	}
	return res;
}

class Condition {
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
	Condition e;
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
	string c_code(Symbols s) {
		return s.c_code(s);
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
	override Decl combine(const(Decl) _o) const {
		auto o = cast(State)_o;
		assert(o !is null, "Can't combine state with non-state");
		assert(entry.length == 0 || o.entry.length == 0,
		       "Can't combine two state when they both have entry actions");
		StateTransition[] new_st = st~o.st;
		Stmt[] new_e = entry~o.entry;
		return new State(name, new_e, new_st);
	}
	override string symbol() const {
		return name;
	}
	@property override string str() const {
		auto res = "state("~name~"):\n";
		res ~= "entry: "~entry.str;
		foreach(ste; st)
			res ~= ste.str;
		return res;
	}
	override string c_code(string particle, string prefix, Symbols p) const {
		import std.format : format;
		auto res = format("static inline void %s_state_%s_entry(%s) {\n", prefix, name, particle.param_list);
		res ~= entry.c_code(p);
		res ~= "}\n";
		foreach(i, x; st) {
			res ~= format("static inline void %s_state_%s_event_%s%s(%s, struct event_%s* __event) {\n",
				      prefix, name, x.e.name, i, particle.param_list, x.e.name);
			res ~= st.e.c_code(p);
			res ~= x.c_code(p);
			res ~= "}\n";
		}
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
	override Decl combine(const(Decl) _) const {
		assert(false, "Combining variables with name "~name);
	}
	override string str() const {
		return name ~ ":" ~ ty.str ~ "\n";
	}
	override string symbol() const {
		return name;
	}
	override string c_code(string a, string b, Symbols s) const {
		return "";
	}
}

class Ctor : Decl {
	Stmt[] stmt;
	private string _prefix, _particle;
	this(Stmt[] x) {
		stmt = x;
	}
	override string str() const {
		return "Ctor: " ~ stmt.str;
	}
	override string symbol() const {
		return "_";
	}
	override string c_code(string particle, string prefix, Symbols s) const {
		auto res = "static inline void "~prefix~"_ctor("~particle.param_list~") {\n";
		res ~= stmt.c_code(s)~"}";
		return res;
	}
}

class Event : Decl {
	VarDecl[] member;
	string name;
	this(string x, VarDecl[] vd) {
		member = vd;
		name = x;
	}
	override string str() const {
		return "Event "~name;
	}
	override string symbol() const {
		return name;
	}
	override string c_code(string a, string b, Symbols s) const {
		assert(false);
	}
}
