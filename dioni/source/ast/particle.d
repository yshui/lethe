module ast.particle;
import ast.decl, ast.symbols;
class Particle : Decl {
	Decl[] decl;
	string name;
	string[] tag;
	string[] component_str;
	Particle[] component;
	private Particle p;
	private Symbols s;
	private bool _visited, _visiting;
	override size_t toHash() {
		return name.toHash();
	}
	override Decl combine(const(Decl) _) const {
		assert(false);
	}
	@property nothrow pure bool visited() const {
		return _visited;
	}
	this(string xn, string[] t, string[] com, Decl[] d) {
		decl = d;
		name = xn;
		component_str = com;
		tag = t;
	}
	override string c_code(string particle, string prefix, Symbols xs) const {
		return c_code;
	}
	string c_code() const {
		int this_count = 0;
		foreach(d; decl) {
			if (d.symbol == "this") {
				import std.conv : to;
				d.prefix = name~to!string(this_count);
				this_count++;
			} else
				d.prefix = name;
			d.particle = name;
		}
		auto res = "";
		foreach(d; decl)
			res ~= d.c_code(s);
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
			foreach(c; p.component)
				dict[c] = true;
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
			if (t[0] == '-')
				tagd[t[1..$]] = false;
			else
				tagd[t] = true;
		}
		tag = tagd.keys;

		//Now generate the symbols, try to combine them when duplicates are found
		foreach(d; decl) {
			if (cast(Ctor)d !is null)
				continue;
			s.insert(d);
		}
		foreach(c; component) {
			foreach(od; c.s.table) {
				auto d = s.lookup(od.symbol);
				if (d is null)
					s.insert(d);
				else
					s.replace(d.combine(od));
			}
		}

		_visited = true;
		_visiting = false;
	}
	override @property nothrow pure string str() const {
		auto res = "particle " ~ name;
		if (parent !is null)
			res ~= ":" ~ parent ~ "{\n";
		else
			res ~= "{\n";
		foreach(d; decl)
			res ~= d.str;
		res ~= "}";
		return res;
	}
	private pure string bare_c_struct(StorageClass sc) const {
		auto res = "";
		foreach(c; component)
			res ~= c.bare_c_struct(sc);
		res ~= s.c_defs(sc);
		return res;
	}
	@property pure string c_structs() const {
		auto res = "struct "~name~" {\n"~bare_c_struct(StorageClass.Particle)~"};\n";
		res ~= "struct "~name~"_shared {\n"~bare_c_struct(StorageClass.Shared)~"};";
		return res;
	}
	override string symbol() const {
		return name;
	}

	alias toString = str;
}
