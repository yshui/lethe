module ast.decl.particle;
import ast.decl, ast.symbols, ast.aggregator;
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
	override {
		size_t toHash() {
			return hashOf(name);
		}
		Decl combine(const(Decl) _) const {
			assert(false);
		}
		void parent(Decl p) {
			assert(false);
		}
		string c_code(const(Symbols) xs, bool prototype_only) const {
			assert(false);
		}
		string str() const {
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
		string symbol() const {
			return name;
		}

		Decl dup() const {
			assert(false);
		}
		const(Aggregator) aggregator() const {
			return new EventAggregator;
		}
	}
@safe :
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
			auto d = glob.lookup_local(c);
			assert(d !is null, "Mixin particle "~c~" not found");
			auto p = cast(Particle)d;
			assert(d !is null, c~" is not a particle");
			p.resolve(glob);
			foreach(dep; p.component)
				dict[dep] = true;
			dict[p] = true;
		}

		//Generate tags
		tag = () @trusted {
			//trusted function because .keys is not @safe
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
			return tagd.keys;
		}();

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
			foreach(od; c.decl) {
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
		s.insert(new HitboxQ);

		auto nil = new State("Nil", [], []);
		nil.parent = this;
		s.insert(nil);

		auto del = new State("Deleted", [], []);
		del.parent = this;
		s.insert(del);

		_visited = true;
		_visiting = false;
	}
	private pure string bare_c_struct(StorageClass sc) const {
		auto res = "struct particle *__p;\n";
		res ~= s.c_defs(sc);
		return res;
	}
	@property pure string c_structs() const {
		auto res = "struct "~name~" {\n"~bare_c_struct(StorageClass.Particle)~"};\n";
		return res;
	}
	pure string c_macros() const {
		import std.conv;
		auto res = "#define PARTICLE_"~name~"_STATE_Nil 0\n";
		res ~= "#define PARTICLE_"~name~"_STATE_Deleted 1\n";
		int id = 2;
		foreach(d; s.table) {
			auto sd = cast(const(State))d;
			if (sd is null)
				continue;
			if (sd.symbol == "Nil" || sd.symbol == "Deleted")
				continue;
			res ~= "#define PARTICLE_"~name~"_STATE_"~sd.symbol~" "~to!string(id)~"\n";
			id ++;
		}
		return res;
	}
	string c_create(bool internal, bool prototype_only=false) const {
		string res = "";
		if (ctor !is null)
			res ~= ctor.c_code(s, prototype_only)~"\n";
		if (internal)
			res ~= "static inline size_t ";
		else
			res ~= "struct particle *";
		res ~= "new_particle_"~name~"(";
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
		res ~= q{struct }~name~q{ *__current = &__p->data[0].}~name;
		res ~= q{, *__next = (void *)&__p->data[1].}~name~";";
		res ~= "\n__current->__p = __next->__p = __p;";
		if (ctor !is null) {
			res ~= "\n"~name~"_ctor(__next, __current";
			foreach(p; ctor.param)
				res ~= ", "~p;
			res ~= ");";
		}
		res ~= "\n*__next = *__current;";
		if (internal)
			res ~= "\nreturn (size_t)__p;";
		else
			res ~= "\nreturn __p;";
		res ~= "\n}\n";
		return res;
	}
	string d_create_proto() const {
		string res = "dioniParticle* new_particle_"~name~"(";
		if (ctor !is null)
			foreach(i, p; ctor.param_def) {
				if (i != 0)
					res ~= ", ";
				res ~= p.ty.d_type~" "~p.symbol;
			}
		return res~");\n";
	}
	string c_run(bool prototype_only=false) const {
		string res = format("int run_particle_%s(struct %s *__current,"~
		    "struct %s *__next, struct event *__event, int state)",
		    name, name, name);
		if (prototype_only)
			return res~";\n";
		res ~= " {\n";
		/*
		foreach(d; s.table) {
			//First, let's propagate data from __current to __next
			auto vd = cast(const(Var))d;
			if (vd is null)
				continue;
			res ~= "\t"~vd.ty.c_copy(vd.c_access, vd.c_access(true))~";\n";
		}*/
		res ~= "\tswitch(state) {\n";
		foreach(d; s.table) {
			auto sd = cast(const(State))d;
			if (sd is null)
				continue;
			res ~= "\tcase PARTICLE_"~name~"_STATE_"~sd.symbol~":\n";
			res ~= "\t\treturn "~name~"_state_"~sd.symbol~"(__current, __next, __event);\n";
		}
		res ~= "\t}\n\tassert(false);\n}\n";
		return res;
	}
}
