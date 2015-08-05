module ast.decl.decl;
import ast.type,
       ast.stmt,
       ast.symbols,
       ast.expr,
       ast.decl,
       ast.match,
       ast.aggregator;
import std.typecons;
import std.string : format;
import mustache;

alias MustacheEngine!string Mustache;

immutable(Aggregator) eagg = new EventAggregator;
immutable(Aggregator) rqagg = new RenderAggregator;
immutable(Aggregator) hbagg = new HitboxAggregator;

class Decl {
	nothrow pure @safe {
		@property {
			void parent(Decl p) { assert(false); }
			string symbol() const { assert(false); }
			string str() const { assert(false); }
			const(Aggregator) aggregator() const { return null; }
		}
		final override string toString() const {
			return str;
		}
		Decl combine(const(Decl) o) const { assert(false); }
		Decl dup() const { assert(false); }
	}
	@safe string c_code(const(Symbols) s, bool prototype_only=false) const {
		assert(false);
	}
}

class Func : Decl {
	string name;
	Var[] param;
	Stmt[] bdy;
override :
	string symbol() const {
		//Mangling
		auto res = name~to!string(param.length);
		foreach(p; param) {
			res ~= "_"~p.ty.mangle;
		}
		return res;
	}
	string str() const {
		return "Func "~name~bdy.str;
	}
	string c_code(const(Symbols) s, bool prototype_only) const {
		if (prototype_only)
			return "";
		auto func_template = import("funcdecl.mustache");
		Mustache r;
		auto ctx = new Mustache.Context;

		ctx["name"] = symbol;

		auto plist = "";
		auto ns = new Symbols(s);
		foreach(i, p; param) {
			if (i != 0)
				plist ~= ", ";
			plist ~= p.ty.c_type~" "~p.name;
			ns.insert(new Var(p.ty, p.aggregator, p.name));
		}
		ctx["param"] = plist;

		bool changed;
		auto code = bdy.c_code(ns, changed);
		return r.renderString(func_template, ctx);
	}
}

class EventParameter {
	const(ParticleMatch) pm;
	const(Cmp) cmp;
@safe :
	pure nothrow {
		this(ParticleMatch x) {
			cmp = null;
			pm = x;
		}
		this(Cmp x) {
			auto v = cast(VarVal)x.lhs;
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
			assert(ty.type_match!ParticleHandle);
			auto var = new Var(new NamedType!Particle(pm.particle, s),
					   new EventAggregator, pm.var.name);
			s.insert(var);
			return "(((struct particle *)"~emem~")->type == PARTICLE_"~pm.particle~")";
		}
		assert(cmp !is null);
		auto lv = cast(const(VarVal))cmp.lhs;
		TypeBase rty;
		auto rcode = cmp.rhs.c_code(s, rty);
		const(Aggregator) nagg = ty.type_match!ParticleHandle ? new EventAggregator : null;
		auto var = new Var(ty, nagg, lv.name);
		s.insert(var);
		return c_match([emem, rcode], [ty, cast(const(TypeBase))rty], cmp.op);
	}

	string c_code_assign(string emem, const(TypeBase) ty) const {
		auto cemem = "((struct particle *)"~emem~")";
		if (pm !is null) {
			auto c = cemem~"->data["~cemem~"->current"~"]";
			return pm.var.name~"=&"~c~"."~pm.particle~";\n";
		}
		auto lv = cast(const(VarVal))cmp.lhs;
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
@safe :
	pure nothrow {
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
		auto e = cast(const(Event))s.lookup_checked(name);
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
@safe :
	pure nothrow {
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

		auto nst = new Var(new AnyType, null, "nextState");
		s1.insert(nst);
		bool changed;
		auto scode = s.c_code(s1, sha, changed);
		s1.merge_shadowed(sha);
		auto vd = cast(const(Var))s1.lookup_checked("nextState");
		assert(vd.ty.type_match!(Type!State), "nextState is not assigned a state");

		res ~= s1.c_defs(StorageClass.Local);
		res ~= cond[1];
		res ~= scode;

		if (changed)
			res ~= "mark_particle_as_changed(__current->__p);\n";

		res ~= "return nextState;\n";
		res ~= "}\n";
		if (cond[0] != "")
			res ~= "}\n";
		return res;
	}
}

@safe pure nothrow string param_list(string particle) {
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
		auto res = format("static inline void %s_state_%s_entry(%s)",
				  _parent.symbol, name, _parent.symbol.param_list);
		if (prototype_only)
			res ~= ";\n";
		else {
			bool changed;
			res ~= " {\n"~entry.c_code(p, changed);
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
	const(Aggregator) aggregator() const {
		return null;
	}
}
enum StorageClass {
	Local,
	Particle,
	Void //No real storage, this variable can't be read
}

enum Protection {
	Const,
	ReadWrite,
}

class Var : Decl {
	const(TypeBase) ty;
	const(Aggregator) agg;
	string name;
	StorageClass sc;
	Protection prot;
	Particle _parent;
pure nothrow @safe :
	string c_access(bool next=false) const {
		import std.exception : assumeWontThrow;
		assert(sc != StorageClass.Void);
		auto src = next ? "next" : "current";
		final switch(sc) {
		case StorageClass.Particle:
			return assumeWontThrow(format("(__%s->%s)", src, name));
		case StorageClass.Local:
			return assumeWontThrow(format("(%s)", name));
		case StorageClass.Void:
			assert(false, name~" can't be read");
		}
	}
	this(const(TypeBase) xty, const(Aggregator) xa,
	     string xname, Protection xprot=Protection.ReadWrite,
	     StorageClass xsc=StorageClass.Local) {
		name = xname;
		sc = xsc;
		ty = xty;
		prot = xprot;
		agg = xa;
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
	Decl dup() const {
		return new Var(ty, null, name, prot, sc);
	}
	const(Aggregator) aggregator() const {
		return agg;
	}
}

class Ctor : Decl {
	Stmt[] stmt;
	Decl[] param;
	const(Var)[] param_def;
	private string _prefix, _particle;
	Particle _parent;
	@safe this(Decl[] p, Stmt[] x) {
		stmt = x;
		param = p;
	}
	@safe string param_list(bool d)(const(Symbols) s) const {
		auto res = "";
		assert(_parent !is null);
		foreach(i, p; param_def) {
			if (i != 0)
				res ~= ", ";
			static if (d)
				res ~= p.ty.d_type~" "~p.name;
			else
				res ~= p.ty.c_type~" "~p.name;
		}
		return res;
	}
	alias c_param_list = param_list!false;
	alias d_param_list = param_list!true;
override :
	void parent(Decl prnt) {
		_parent = cast(Particle)prnt;
		assert(_parent !is null);
		auto s = _parent.sym;
		foreach(p; param) {
			auto vp = cast(Var)p;
			if (vp.ty.type_match!AnyType) {
				auto vd = cast(const(Var))s.lookup_checked(vp.name);
				assert(vd !is null, vp.name~" is not a variable");
				assert(vd.sc == StorageClass.Particle);
				param_def ~= vd;
			} else {
				vp.sc = StorageClass.Local;
				param_def ~= vp;
			}
		}
	}
	string str() const {
		return "Ctor: " ~ stmt.str;
	}
	string symbol() const {
		return "_";
	}
	string c_code(const(Symbols) s, bool prototype_only) const {
		assert(_parent !is null);
		auto res = "static inline void "~_parent.symbol~"_ctor("~_parent.symbol.param_list;
		res ~= ", "~c_param_list(s);
		if (prototype_only)
			return res~");";

		auto ns = new Symbols(s);
		res ~= ") {\n";
		foreach(p; param_def) {
			if (p.sc == StorageClass.Particle) {
				res ~= p.c_access(false)~" = "~p.name~";\n";
				res ~= p.c_access(true)~" = "~p.name~";\n";
			} else
				ns.insert(new Var(p.ty, null, p.name));
		}
		//Initialize variables in the param
		bool changed;
		res ~= stmt.c_code(ns, changed)~"}";
		return res;
	}
}

class Event : Decl {
	TypeBase[] member;
	string name;
	@safe this(string x, TypeBase[] vd) {
		member = vd;
		name = x;
	}
	@safe string c_structs() const {
		import std.conv : to;
		string res = "struct event_"~name~"{\n";
		foreach(i, ty; member)
			res ~= ty.c_type~" m"~to!string(i)~";\n";
		res ~= "};\n";
		return res;
	}
	@safe string d_structs() const {
		import std.conv : to;
		string res = "struct dioniEvent_"~name~"{\n";
		foreach(i, ty; member)
			res ~= ty.d_type~" m"~to!string(i)~";\n";
		res ~= "};\n";
		return res;
	}
override :
	string str() const {
		return "Event "~name;
	}
	string symbol() const {
		return name;
	}
}

class Tag : Decl {
	string name;
	@safe this(string x) { name = x; }
	pure nothrow @safe string c_access() const {
		return "(TAG_"~name~")";
	}
override :
	string str() const {
		return "Tag "~name;
	}
	string symbol() const {
		return name;
	}
	const(Aggregator) aggregator() const {
		return eagg;
	}
}
class Vertex : Decl {
	string name;
	Var[] member;
	Var[string] map;
	@safe this(string x, Var[] vd) {
		name = x;
		member = vd;
		foreach(v; member)
			map[v.name] = v;
	}
	@safe string c_structs() {
		import std.conv : to;
		string res = "struct vertex_"~name~"{\n";
		foreach(i, v; member)
			res ~= v.ty.c_type~" "~v.name~";\n";
		res ~= "}__attribute__((packed));\n";
		return res;
	}
	@safe string d_structs() {
		import std.conv : to;
		string res = "struct vertex_"~name~"{\n";
		res ~= "align(1):\n";
		foreach(i, v; member)
			res ~= v.ty.d_type~" "~v.name~";\n";
		res ~= "}\n";
		return res;
	}
override :
	string str() const {
		return "Vertex "~name;
	}
	string symbol() const {
		return name;
	}
}

class RenderQ : Decl {
	string name;
	int id;
	NamedType!Vertex ty;
	@safe this(string xname, int xid, TypeBase tb) {
		id = xid;
		name = xname;
		ty = cast(NamedType!Vertex)tb;
		assert(ty !is null);
	}
override :
	string str() const {
		return "RenderQ "~name;
	}
	string symbol() const {
		return name;
	}
	const(Aggregator) aggregator() const {
		return rqagg;
	}
}

class HitboxQ : Decl {
override :
	string str() const {
		return "HitboxQ";
	}
	string symbol() const {
		return "hitboxes";
	}
	const(Aggregator) aggregator() const {
		return hbagg;
	}
}
