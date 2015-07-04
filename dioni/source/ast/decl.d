module ast.decl;
import ast.type,
       ast.stmt,
       ast.symbols,
       ast.expr,
       ast.particle;

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
	string[2] c_code(Symbols s) const {
		//Generate c code for matching
		int count = 0;
		auto d = s.lookup(name);
		assert(d !is null, "Event "~name~" is not defined");
		auto e = cast(Event)d;
		assert(e !is null, name~" is not an event definition");

		auto mcode = "", acode = "";

		foreach(i, x; ep) {
			auto vd = e.member[i];
			auto pt = cast(ParticleType)vd.ty;
			if (x.expr is null) {
				if (x.var is null)
					continue;
				assert(pt is null,
				       "Cannot determine the actual type of a "~
				       "particle without matching criteria");
				acode ~= x.var.name~" = "~"__event->"~vd.symbol~";\n";
				auto mv = new VarDecl(vd.ty, x.var.name, Protection.Const);
				s.insert(mv);
			}
			if (count != 0)
				mcode ~= " && ";
			if (pt is null) {
				TypeBase ety;
				auto ecode = x.expr.c_code(s, ety);
				assert(typeid(ety) == typeid(Type!int),
				       "Trying to match 'int' against"~
				       ety.c_type);
				mcode ~= "(__event->"~vd.symbol~" == "~ecode~")";
				count ++;
			} else {
				//Trying to match a particle
				auto ev = cast(Var)x.expr;
				assert(ev !is null, "Particle can only be matched against a name");
				auto d2 = s.lookup(ev.name);
				assert(d !is null, ev.name~" is not defined");
				auto p = cast(Particle)d;
				assert(p !is null, ev.name~" does not name a particle");
				if (x.var !is null)
					acode ~= x.var.name~" = "~"__event->"~vd.symbol~".p"~";\n";
				mcode ~= "(__event->"~vd.symbol~".t == PARTICLE_"~ev.name~")";
			}
		}
		return [acode, mcode];
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
		auto s1 = new Symbols(p);
		string[2] cond = e.c_code(s1);
		auto res = "if (__raw_event->t == EVENT_"~e.name~") {";
		res ~= "struct event_"~e.name~"* __event = __raw_event->e;\n";
		res ~= "if ("~cond[0]~") {";
		res ~= s1.c_defs(StorageClass.Local);
		res ~= cond[1];
		res ~= s.c_code(p);
		res ~= "return nextState;\n";
		res ~= "}\n}\n";
		return res;
	}
}

pure nothrow string param_list(string particle) {
	string res;
	immutable string[] names = ["__current", "__next"];
	foreach(i, n; names) {
		if (i != 0)
			res ~= ", ";
		res ~= "struct "~particle~"* "~n;
	}
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
		res ~= format("static inline void %s_state_%s(%s, struct event_%s* __raw_event) {\n",
			      prefix, name, particle.param_list);
		foreach(x; st)
			res ~= x.c_code(p);
		return res;
	}
}
enum StorageClass {
	Local,
	Particle,
}

enum Protection {
	Const,
	ReadWrite,
}

class VarDecl : Decl {
	const(TypeBase) ty;
	string name;
	StorageClass sc;
	Protection prot;
	pure nothrow this(const(TypeBase) xty, string xname,
			  Protection xprot=Protection.ReadWrite,
		  StorageClass xsc=StorageClass.Local) {
		name = xname;
		sc = xsc;
		ty = xty;
		prot = xprot;
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
	string c_structs() const {
		string res = "struct event_"~name~"{\n";
		foreach(vd; member)
			res ~= vd.ty.c_type~" "~vd.symbol~"\n";
		res ~= "}";
		return res;
	}
	alias toString = str;
}
