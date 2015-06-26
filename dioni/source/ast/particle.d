module ast.particle;
import ast.decl;
class Particle {
	Decl[] decl;
	string name, parent;
	this(string xn, string xp, Decl[] d) {
		decl = d;
		name = xn;
		parent = xp;
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
	alias toString = str;
}
