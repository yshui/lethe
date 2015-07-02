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
	string c_code(string particle, string prefix, const(Symbols) s) const;
	pure nothrow Decl combine(const(Decl) o) const;
}

class EventParameter {
	Var var;
	Expr expr;
	this(Var v, Expr e) {
		var = v;
		expr = e;
	}
	nothrow pure string str() const {
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

package pure nothrow string str_ep(const(EventParameter)[] ep) {
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
	const(EventParameter)[] ep;
	this(string xname, const(EventParameter)[] xep) {
		ep = xep;
		name = xname;
	}
	pure nothrow string str() const {
		return name ~ "(" ~ ep.str_ep ~ ")";
	}
}

class StateTransition {
	Condition e;
	string next;
	const(Stmt)[] s;
	this(Condition xe, const(Stmt)[] xs, string xnext) {
		e = xe;
		s = xs;
		next = xnext;
	}
	pure nothrow string str() const {
		auto res = "On event " ~ e.str ~ " do:\n";
		res ~= s.str;
		res ~= "=> " ~ next ~ "\n";
		return res;
	}
	string c_code(const(Symbols) p) const {
		return s.c_code(p);
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
	const(StateTransition)[] st;
	const(Stmt)[] entry;
	string name;
	private string _prefix, _particle;
	nothrow pure this(string xname, const(Stmt)[] e, const(StateTransition)[] xst) {
		name = xname;
		st = xst is null ? [] : xst;
		entry = e;
	}
	override Decl combine(const(Decl) _o) const {
		auto o = cast(State)_o;
		assert(o !is null, "Can't combine state with non-state");
		const(StateTransition)[] new_st = st~o.st;

		//Allow new entry action to override the old one
		const(Stmt)[] new_e;
		if (entry.length != 0)
			new_e = entry;
		else
			new_e = o.entry;

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
	override string c_code(string particle, string prefix, const(Symbols) p) const {
		import std.format : format;
		auto res = format("static inline void %s_state_%s_entry(%s) {\n", prefix, name, particle.param_list);
		res ~= entry.c_code(p);
		res ~= "}\n";
		foreach(i, x; st) {
			res ~= format("static inline void %s_state_%s_event_%s%s(%s, struct event_%s* __event) {\n",
				      prefix, name, x.e.name, i, particle.param_list, x.e.name);
			//res ~= st.e.c_code(p); //Generate code for matching the condition TODO
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
	override string c_code(string a, string b, const(Symbols) s) const {
		return "";
	}
	string c_access(bool next=false) const {
		import std.format : format;
		auto src = next ? "next" : "current";
		final switch(sc) {
		case StorageClass.Particle:
			return format("(__%s->%s)", src, name);
		case StorageClass.Shared:
			return format("(__shared_%s->%s)", src, name);
		case StorageClass.Local:
			return format("(%s)", name);
		}
	}
}

class Ctor : Decl {
	Stmt[] stmt;
	string[] param;
	private string _prefix, _particle;
	this(string[] p, Stmt[] x) {
		stmt = x;
		param = p;
	}
	override string str() const {
		return "Ctor: " ~ stmt.str;
	}
	override string symbol() const {
		return "_";
	}
	override Decl combine(const(Decl) _) const {
		assert(false);
	}
	override string c_code(string particle, string prefix, const(Symbols) s) const {
		auto res = "static inline void "~prefix~"_ctor("~particle.param_list;
		auto init = "";
		foreach(p; param) {
			auto d = s.lookup(p);
			assert(d !is null, p~" is not a member, "~
			       "thus can't be part of initialize list");
			auto vd = cast(VarDecl)d;
			assert(vd !is null, p~" is not a variable");
			res ~= ", "~vd.ty.c_type~" "~vd.name;
			init ~= vd.c_access(true)~" = "~p~";\n";
		}
		res ~= ") {\n"~init;
		//Initialize variables in the param
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
	override Decl combine(const(Decl) _) const {
		assert(false);
	}
	override string str() const {
		return "Event "~name;
	}
	override string symbol() const {
		return name;
	}
	override string c_code(string a, string b, const(Symbols) s) const {
		assert(false);
	}
}
