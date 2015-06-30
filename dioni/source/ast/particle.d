module ast.particle;
import ast.decl, ast.symbols;
class Particle : Decl {
	Decl[] decl;
	string name, parent;
	private Particle p;
	private Symbols s;
	private bool _visited, _visiting;
	@property nothrow pure bool visited() const {
		return _visited;
	}
	this(string xn, string xp, Decl[] d) {
		decl = d;
		name = xn;
		parent = xp;
	}
	override void prefix(string x) {
		assert(false);
	}
	override void particle(string x) {
		assert(false);
	}
	override string c_code(Symbols xs) {
		return c_code;
	}
	string c_code() {
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
	void gen_symbols(Symbols glob) {
		if (_visited)
			return;

		assert(!_visiting, "Possible inheritance circle");
		_visiting = true;
		if (parent !is null) {
			auto d = glob.lookup(parent);
			assert(d !is null, "Base particle "~parent~" not found");
			auto p = cast(Particle)d;
			assert(d !is null, parent~" is not a particle");
			p.gen_symbols(glob);
			s = new Symbols(p.s);
		} else
			s = new Symbols(null);
		foreach(d; decl) {
			if (d.symbol == "this") {
				auto c = cast(Ctor)d;
				assert(c !is null, "Can't have variable/state named 'this'");
				continue;
			}
			s.insert(d, true);
		}
		_visited = true;
		_visiting = false;
	}
	override @property nothrow pure string str() {
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
	pure string bare_c_struct(StorageClass sc) {
		auto res = "";
		if (p !is null)
			res = p.bare_c_struct(sc);
		res ~= s.c_defs(sc);
		return res;
	}
	@property pure string c_structs() {
		auto res = "struct "~name~" {\n"~bare_c_struct(StorageClass.Particle)~"};\n";
		res ~= "struct "~name~"_shared {\n"~bare_c_struct(StorageClass.Shared)~"};";
		return res;
	}
	override string symbol() {
		return name;
	}

	alias toString = str;
}
