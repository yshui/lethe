module ast.particle;
import ast.decl, ast.symbols;
class Particle : Decl {
	Decl[] decl;
	string name, parent;
	private Particle p;
	private Symbols s;
	private bool _visited;
	@property nothrow pure bool visited() const {
		return _visited;
	}
	this(string xn, string xp, Decl[] d) {
		decl = d;
		name = xn;
		parent = xp;
	}
	override void set_prefix(string x) {
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
				d.set_prefix(name~to!string(this_count));
				this_count++;
			} else
				d.set_prefix(name);
		}
		auto res = "";
		foreach(d; decl)
			res ~= d.c_code(s);
		return res;
	}
	void gen_symbols(Symbols glob) {
		assert(!_visited, "Possible inheritance circle");
		_visited = true;
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
	@property pure string bare_c_struct() {
		auto res = "";
		if (p !is null)
			res = p.bare_c_struct;
		res ~= s.c_defs;
		return res;
	}
	@property pure string c_struct() {
		return "struct " ~ name ~ " {\n" ~ bare_c_struct ~ "};";
	}
	override string symbol() {
		return name;
	}

	alias toString = str;
}
