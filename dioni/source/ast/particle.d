module ast.particle;
import ast.decl, ast.symbols;
class ProxyDecl : Decl {
	Decl d;
	Particle owner;
	override string symbol() {
		return d.symbol;
	}
	string c_code(string particle, string prefix, Symbols s) {
		return d.c_code(particle, prefix, s);
	}
}
class Particle : Decl {
	Decl[] decl;
	string name;
	string[] tag;
	string[] component_str;
	Particle[] component;
	private Particle p;
	private Symbols s;
	private bool _visited, _visiting;
	@property nothrow pure bool visited() const {
		return _visited;
	}
	this(string xn, string t[], string com[], Decl[] d) {
		decl = d;
		name = xn;
		component_str = com;
		tag = t;
	}
	override string c_code(string particle, string prefix, Symbols xs) {
		return c_code;
	}
	const(Decl)[] local_decl() const {
		const(Decl)[] ret = [];
		foreach(d; decl) {
			if (d.symbol == "this")
				continue;
			ret ~= d;
		}
		return ret;
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
		s = new Symbols(glob);
		foreach(c; component_str) {
			auto d = glob.lookup(c);
			assert(d !is null, "Mixin particle "~c~" not found");
			auto p = cast(Particle)d;
			assert(d !is null, c~" is not a particle");
			p.gen_symbols(glob);
			component ~= [p];
		}
		foreach(d; decl) {
			if (d.symbol == "this") {
				auto c = cast(Ctor)d;
				assert(c !is null, "Can't have variable/state named 'this'");
				continue;
			}
			s.insert(d);
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
	private pure string bare_c_struct(string suffix, StorageClass sc) {
		auto res = "";
		foreach(c; component)
			res ~= "struct "~c~suffix~" p_"~c~";\n";
		res ~= s.c_defs(sc);
		return res;
	}
	@property pure string c_structs() {
		auto res = "struct "~name~" {\n"~bare_c_struct("", StorageClass.Particle)~"};\n";
		res ~= "struct "~name~"_shared {\n"~bare_c_struct("_shared", StorageClass.Shared)~"};";
		return res;
	}
	@property pure string c_forward_defs() {
		return "struct "~name~";\nstruct "~name~"_shared;\n";
	}
	override string symbol() {
		return name;
	}
	Decl member(string symbol) {
		return s.lookup(symbol);
	}
	string c_member_var(string symbol) {
		auto d = s.lookup(symbol);
		assert(d !is null, "Accessing non-existent member "~symbol);
		auto vd = cast(VarDecl)d;
		assert(vd !is null, "Using non-variable member '"~symbol~"' as variable");

		

	alias toString = str;
}
