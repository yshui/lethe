module ast.symbols;
import ast.decl;
class Symbols {
	Decl[string] table;
	Symbols parent;
	pure nothrow Decl lookup(string name) {
		if (name is null)
			return null;
		if ((name in table) !is null)
			return table[name];
		if (parent !is null)
			return parent.lookup(name);
		else
			return null;
	}
	void insert(Decl d, bool over=false) {
		assert((d.symbol in reserved_names) is null, "Reserved name "~d.symbol);
		assert(lookup(d.symbol) is null || over, "Duplicated name "~d.symbol);
		table[d.symbol] = d;
	}
	this(Symbols p) {
		parent = p;
	}
	@property pure string c_defs() const {
		string res = "";
		foreach(d; table) {
			auto vd = cast(VarDecl)d;
			if (vd is null)
				continue;
			res ~= vd.ty.c_type~" "~vd.symbol~";\n";
		}
		return res;
	}
}

immutable bool[string] reserved_names;

static this() {
	string[] ns = ["__current", "__next"];
	foreach(n; ns)
		reserved_names[n] = true;
}
