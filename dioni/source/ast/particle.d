module ast.particle;
import ast.decl, ast.symbols;
class Particle : Decl {
	Decl[] decl;
	string name, parent;
	Symbols s;
	this(string xn, string xp, Decl[] d) {
		decl = d;
		name = xn;
		parent = xp;
	}
	void populate_symbols(Symbols p) {
		s = new Symbols(p);
		foreach(d; decl) {
			if (d.symbol == "this") {
				auto c = cast(Ctor)d;
				assert(c !is null, "Can't have variable/state named 'this'");
				continue;
			}
			s.insert(d);
		}
	}
	@property nothrow pure string str() {
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
	@property nothrow pure string bare_c_struct() {
		auto res = "";
		auto pd = s.lookup(parent);
		Particle p;
		if (pd !is null)
			p = cast(Particle)pd;
		if (p !is null)
			res = p.bare_c_struct;
		foreach(d; decl) {
			auto v = cast(VarDecl)d;
			if (v is null)
				continue;
			res ~= v.ty.c_type ~ " " ~ v.name ~ ";\n";
		}
		return res;
	}
	@property nothrow pure string c_struct() {
		return "struct " ~ name ~ " {\n" ~ bare_c_struct ~ "};";
	}
	string symbol() {
		return name;
	}

	alias toString = str;
}
