module ast.symbols;
import ast.decl;
class Symbols {
	Decl[string] table;
	const(Symbols) parent;
	pure nothrow const(Decl) lookup(string name) const {
		if (name is null)
			return null;
		if ((name in table) !is null)
			return table[name];
		if (parent !is null)
			return parent.lookup(name);
		else
			return null;
	}
	void insert(const(Decl) d) {
		assert((d.symbol in reserved_names) is null, "Reserved name "~d.symbol);
		assert(lookup(d.symbol) is null, "Duplicated name "~d.symbol);
		table[d.symbol] = cast(Decl)d;
	}
	void replace(Decl d) {
		if ((d.symbol in table) is null) {
			insert(d);
			return;
		}
		table[d.symbol] = d;
	}
	pure this(const(Symbols) p) {
		parent = p;
	}
	pure string c_defs(StorageClass sc) const {
		string res = "";
		foreach(d; table) {
			auto vd = cast(VarDecl)d;
			if (vd is null)
				continue;
			if (vd.sc != sc)
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
