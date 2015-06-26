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
	void insert(Decl d) {
		assert(lookup(d.symbol) is null, "Duplicated name "~d.symbol);
		table[d.symbol] = d;
	}
	this(Symbols p) {
		parent = p;
	}
}
