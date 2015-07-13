module ast.decl.decl;
import ast.type,
       ast.stmt,
       ast.symbols,
       ast.expr,
       ast.decl,
       ast.match;
import std.typecons;

interface Decl {
	nothrow pure @safe {
		@property void parent(Decl p);
		@property string symbol() const;
		@property string str() const;
		final string toString() const {
			return str;
		}
		Decl combine(const(Decl) o) const;
		Decl dup() const;
	}
	string c_code(const(Symbols) s, bool prototype_only=false) const;
}

class EventParameter {
	const(ParticleMatch) pm;
	const(Cmp) cmp;
	pure nothrow @safe {
		this(ParticleMatch x) {
			cmp = null;
			pm = x;
		}
		this(Cmp x) {
			auto v = cast(Var)x.lhs;
			assert(v !is null);
			cmp = x;
			pm = null;
		}
		string str() const {
			if (pm !is null)
				return pm.str;
			else
				return cmp.str;
		}
	}
	string c_code_match(string emem, const(TypeBase) ty, Symbols s) const {
		if (pm !is null) {
			assert(typeid(ty) == typeid(UDType));
			auto var = new VarDecl(new UDType(pm.particle, s), pm.var.name);
			s.insert(var);
			return "("~emem~".t == PARTICLE_"~pm.particle~")";
		}
		assert(cmp !is null);
		auto lv = cast(Var)cmp.lhs;
		TypeBase rty;
		auto rcode = cmp.rhs.c_code(s, rty);
		auto var = new VarDecl(ty, lv.name);
		s.insert(var);
		return c_match([emem, rcode], [ty, cast(const(TypeBase))rty], cmp.op);
	}

	string c_code_assign(string emem, const(TypeBase) ty) const {
		if (pm !is null)
			return pm.var.name~"="~emem~".p"~";\n";
		auto lv = cast(Var)cmp.lhs;
		if (typeid(ty) == typeid(UDType))
			return lv.name~"="~emem~".id"~";\n";
		return lv.name~"="~emem~";\n";
	}
}

package pure nothrow @safe string str_ep(const(EventParameter)[] ep) {
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
	pure nothrow @safe {
		this(string xname, const(EventParameter)[] xep) {
			ep = xep;
			name = xname;
		}
		string str() const {
			return name ~ "(" ~ ep.str_ep ~ ")";
		}
	}
	string[2] c_code(Symbols s) const {
		//Generate c code for matching
		import std.conv : to;
		int count = 0;
		auto e = cast(Event)s.lookup_checked(name);
		assert(e !is null, name~" is not an event definition");

		auto mcode = "", acode = "";

		foreach(i, x; ep) {
			auto ty = e.member[i];
			auto emn = "(__event->m"~to!string(i)~")";
			mcode ~= x.c_code_match(emn, ty, s);
			acode ~= x.c_code_assign(emn, ty);
		}
		return [mcode, acode];
	}
}

class StateTransition {
	Condition e;
	const(Stmt)[] s;
	pure nothrow @safe {
		this(Condition xe, const(Stmt)[] xs) {
			e = xe;
			s = xs;
		}
		string str() const {
			auto res = "On event " ~ e.str ~ " do:\n";
			res ~= s.str;
			return res;
		}
	}
	string c_code(const(Symbols) p) const {
		auto s1 = new Symbols(p);
		Shadows sha;
		string[2] cond = e.c_code(s1);
		auto res = "if (__raw_event->event_type == EVENT_"~e.name~") {\n";
		res ~= "struct event_"~e.name~"* __event = &__raw_event->e."~e.name~";\n";
		if (cond[0] != "")
			res ~= "if ("~cond[0]~") {\n";

		auto nst = new VarDecl(new AnonymousType, "nextState");
		s1.insert(nst);
		auto scode = s.c_code(s1, sha);
		s1.merge_shadowed(sha);
		auto vd = cast(VarDecl)s1.lookup_checked("nextState");
		assert(vd.ty.type_match!StateType, "nextState is not assigned a state");

		res ~= s1.c_defs(StorageClass.Local);
		res ~= cond[1];
		res ~= s.c_code(s1, sha);

		res ~= "return nextState;\n";
		res ~= "}\n";
		if (cond[0] != "")
			res ~= "}\n";
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
	private Particle _parent;
	string name;
	private string _prefix, _particle;
	pure nothrow @safe {
		const(Particle) parent() const {
			return _parent;
		}
		this(string xname, const(Stmt)[] e, const(StateTransition)[] xst) {
			name = xname;
			st = xst is null ? [] : xst;
			entry = e;
		}
		string c_access() const {
			assert(_parent !is null);
			return "(PARTICLE_"~_parent.symbol~"_STATE_"~name~")";
		}
	}
override :
	void parent(Decl p) {
		_parent = cast(Particle)p;
		assert(_parent !is null);
	}
	Decl combine(const(Decl) _o) const {
		auto o = cast(const(State))_o;
		assert(o !is null, "Can't combine state with non-state");
		const(StateTransition)[] new_st = st~o.st;

		//Allow new entry action to the old one
		const(Stmt)[] new_e;
		if (entry.length != 0)
			new_e = entry;
		else
			new_e = o.entry;

		return new State(name, new_e, new_st);
	}
	string symbol() const {
		return name;
	}
	string str() const {
		auto res = "state("~name~"):\n";
		res ~= "entry: "~entry.str;
		foreach(ste; st)
			res ~= ste.str;
		return res;
	}
	string c_code(const(Symbols) p, bool prototype_only) const {
		assert(_parent !is null);
		import std.format : format;
		auto res = format("static inline void %s_state_%s_entry(%s)",
				  _parent.symbol, name, _parent.symbol.param_list);
		if (prototype_only)
			res ~= ";\n";
		else {
			res ~= " {\n"~entry.c_code(p);
			res ~= "}\n";
		}

		res ~= format("static inline int %s_state_%s(%s, struct event* __raw_event)",
			      _parent.symbol, name, _parent.symbol.param_list);
		if (prototype_only)
			res ~= ";\n";
		else {
			res ~= " {\n";
			foreach(x; st)
				res ~= x.c_code(p);
			res ~= "return NOT_HANDLED;\n";
			res ~= "}\n";
		}
		return res;
	}
	Decl dup() const {
		return new State(name, entry, st);
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
	private Rebindable!(const TypeBase) _ty;
	string name;
	StorageClass sc;
	Protection prot;
	Particle _parent;
pure nothrow @safe :
	string c_access(bool next=false) const {
		import std.format : format;
		import std.exception : assumeWontThrow;
		auto src = next ? "next" : "current";
		final switch(sc) {
		case StorageClass.Particle:
			return assumeWontThrow(format("(__%s->%s)", src, name));
		case StorageClass.Local:
			return assumeWontThrow(format("(%s)", name));
		}
	}
	this(const(TypeBase) xty, string xname,
			  Protection xprot=Protection.ReadWrite,
		  StorageClass xsc=StorageClass.Local) {
		name = xname;
		sc = xsc;
		_ty = xty;
		prot = xprot;
	}
	@property const(TypeBase) ty() const {
		return _ty;
	}
	@property const(TypeBase) ty(const(TypeBase) nty) {
		auto tmp = ty;
		assert(tmp.type_match!AnonymousType);
		_ty = nty;
		return _ty;
	}
override :
	void parent(Decl p) {
		_parent = cast(Particle)p;
		assert(_parent !is null);
	}
	Decl combine(const(Decl) _) const {
		assert(false, "Combining variables with name "~name);
	}
	string str() const {
		return name ~ ":" ~ ty.str ~ "\n";
	}
	string symbol() const {
		return name;
	}
	string c_code(const(Symbols) s, bool prototype_only) const {
		assert(false);
		//return "";
	}
	Decl dup() const {
		return new VarDecl(ty, name, prot, sc);
	}
}

class Ctor : Decl {
	Stmt[] stmt;
	const(VarDecl)[] param_def;
	string[] param;
	private string _prefix, _particle;
	Particle _parent;
	override void parent(Decl prnt) {
		_parent = cast(Particle)prnt;
		assert(_parent !is null);
		auto s = _parent.sym;
		foreach(p; param) {
			auto vd = cast(const(VarDecl))s.lookup_checked(p);
			assert(vd !is null, p~" is not a variable");
			param_def ~= vd;
		}
	}
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
	override string c_code(const(Symbols) s, bool prototype_only) const {
		assert(_parent !is null);
		auto res = "static inline void "~_parent.symbol~"_ctor("~_parent.symbol.param_list;
		auto init = "";
		foreach(p; param_def) {
			res ~= ", "~p.ty.c_type~" "~p.name;
			init ~= p.c_access(true)~" = "~p.name~";\n";
		}
		if (prototype_only)
			return res~");";

		res ~= ") {\n"~init;
		//Initialize variables in the param
		res ~= stmt.c_code(s)~"}";
		return res;
	}
	override Decl dup() const {
		assert(false);
	}
}

class Event : Decl {
	TypeBase[] member;
	string name;
	override void parent(Decl p) {
		assert(false);
	}
	this(string x, TypeBase[] vd) {
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
	override string c_code(const(Symbols) s, bool prototype_only) const {
		assert(false);
	}
	string c_structs() const {
		import std.conv : to;
		string res = "struct event_"~name~"{\n";
		foreach(i, ty; member)
			res ~= ty.c_type~" m"~to!string(i)~";\n";
		res ~= "};\n";
		return res;
	}
	override Decl dup() const {
		assert(false);
	}
}

class Tag : Decl {
	string name;
	override void parent(Decl p) {
		assert(false);
	}
	this(string x) {
		name = x;
	}
	override Decl combine(const(Decl) _) const {
		assert(false);
	}
	override string str() const {
		return "Tag "~name;
	}
	override string symbol() const {
		return name;
	}
	override string c_code(const(Symbols) s, bool prototype_only) const {
		assert(false);
	}
	override Decl dup() const {
		assert(false);
	}
}
