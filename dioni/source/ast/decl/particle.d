module ast.decl.particle;
import ast.decl, ast.symbols;
import std.string;
class Particle : Decl {
	Decl[] decl;
	string name;
	string[] tag;
	private string[] component_str;
	Particle[] component;
	Ctor ctor;
	private Particle p;
	private Symbols s;
	private bool _visited, _visiting;
	override size_t toHash() {
		return hashOf(name);
	}
	override Decl combine(const(Decl) _) const {
		assert(false);
	}
	override void parent(Decl p) {
		assert(false);
	}
	@property nothrow pure bool visited() const {
		return _visited;
	}
	@property nothrow pure @safe const(Symbols) sym() const {
		return s;
	}

	this(string xn, string[] t, string[] com, Decl[] d) {
		decl = d;
		name = xn;
		component_str = com;
		tag = t;
	}
	override string c_code(const(Symbols) xs, bool prototype_only) const {
		assert(false);
	}
	string c_code(bool prototype_only=false) const {
		int this_count = 0;
		auto res = "";
		foreach(d; s.table) {
			auto st = cast(const(State))d;
			if (st is null)
				continue;
			res ~= st.c_code(s, prototype_only);
		}
		return res;
	}
	void resolve(Symbols glob) {
		if (_visited)
			return;
		assert(!_visiting, "Possible inheritance circle");
		_visiting = true;

		s = new Symbols(glob);

		//Get all dependencies of this particle
		bool[Particle] dict;
		foreach(c; component_str) {
			auto d = glob.lookup(c);
			assert(d !is null, "Mixin particle "~c~" not found");
			auto p = cast(Particle)d;
			assert(d !is null, c~" is not a particle");
			p.resolve(glob);
			foreach(dep; p.component)
				dict[dep] = true;
			dict[p] = true;
		}

		//Generate tags
		bool[string] tagd;
		foreach(c; dict.keys) {
			component ~= c;
			foreach(t; c.tag)
				tagd[t] = true;
		}
		foreach(t; tag) {
			auto td = cast(const(Tag))s.lookup_checked(t);
			assert(td !is null, t~" is not a tag");

			if (t[0] == '-')
				tagd[t[1..$]] = false;
			else
				tagd[t] = true;
		}
		tag = tagd.keys;

		//Now generate the symbols, try to combine them when duplicates are found
		foreach(d; decl) {
			d.parent = this;
			if (cast(Ctor)d !is null) {
				assert(ctor is null, "Multiple ctor is not allowed");
				ctor = cast(Ctor)d;
				continue;
			}
			s.insert(d);
		}
		foreach(c; component) {
			foreach(od; c.s.table) {
				auto d = s.lookup(od.symbol);
				if (d is null) {
					auto newd = od.dup;
					newd.parent = this;
					s.insert(newd);
				} else {
					import std.stdio;
					auto tmp = d.combine(od);
					tmp.parent = this;
					writeln(tmp.str);
					s.replace(tmp);
				}
			}
		}

		_visited = true;
		_visiting = false;
	}
	override @property nothrow pure string str() const {
		auto res = "particle " ~ name;
		if (component_str.length != 0)
			res ~= "<<"~component_str.join(", ")~"{\n";
		else
			res ~= "{\n";
		foreach(d; decl)
			res ~= d.str;
		res ~= "}";
		return res;
	}
	private pure string bare_c_struct(StorageClass sc) const {
		auto res = "";
		res ~= s.c_defs(sc);
		return res;
	}
	@property pure string c_structs() const {
		auto res = "struct "~name~" {\n"~bare_c_struct(StorageClass.Particle)~"};\n";
		return res;
	}
	override string symbol() const {
		return name;
	}
	
	override Decl dup() const {
		assert(false);
	}
	pure string c_macros() const {
		import std.conv;
		auto res = "";
		int id = 0;
		foreach(d; s.table) {
			auto sd = cast(State)d;
			if (sd is null)
				continue;
			res ~= "#define PARTICLE_"~name~"_STATE_"~sd.symbol~" "~to!string(id)~"\n";
			id ++;
		}
		return res;
	}
	string c_create(bool prototype_only=false) const {
		string res = "";
		if (ctor !is null)
			res ~= ctor.c_code(s, prototype_only)~"\n";
		res ~= "static inline int new_particle_"~name~"(";
		if (ctor !is null)
			foreach(i, p; ctor.param_def) {
				if (i != 0)
					res ~= ", ";
				res ~= p.ty.c_type~" "~p.symbol;
			}
		if (prototype_only)
			return res~");\n";

		res ~= ") {\n";
		res ~= "struct particle *__p = alloc_particle();\n__p->current = 0;\n";
		res ~= "__p->type = PARTICLE_"~name~";\n";
		if (ctor !is null) {
			res ~= q{struct }~name~q{ *__current = (void *)&__p->data[0], };
			res ~= q{*__next = (void *)&__p->data[1];};
			res ~= "\n"~name~"_ctor(__current, __next";
			foreach(p; ctor.param)
				res ~= ", "~p;
			res ~= ");";
		}
		res ~= "\nreturn get_particle_id(__p);";
		res ~= "\n}\n";
		return res;
	}
	string c_run(bool prototype_only=false) const {
		string res = format("int run_particle_%s(struct %s *__current,"~
		    "struct %s *__next, struct event *__event, int state)",
		    name, name, name);
		if (prototype_only)
			return res~";\n";
		res ~= " {\n\tswitch(state) {\n";
		foreach(d; s.table) {
			auto sd = cast(State)d;
			if (sd is null)
				continue;
			res ~= "\tcase PARTICLE_"~name~"_STATE_"~sd.symbol~":\n";
			res ~= "\t\treturn "~name~"_state_"~sd.symbol~"(__current, __next, __event);\n";
		}
		res ~= "\t}\n\tassert(false);\n}\n";
		return res;
	}
}
