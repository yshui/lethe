module ast.symbols;
import ast.decl;
import std.typecons;
class Shadows {
	const(Symbols) s;
	@safe nothrow {
		int opApply(int delegate(ref const(Decl) d) nothrow @safe dg) {
			try {
				foreach(d; s._shadow) {
					if ((d.symbol in s.table) !is null)
						continue;
					auto ret = dg(d);
					if (ret != 0)
						return ret;
				}
				return 0;
			}catch(Exception e) {
				assert(false, e.msg);
			}
		}
		this(const(Symbols) xs){
			s = xs;
		}
	}
}
class Symbols {
	Rebindable!(const(Decl))[string] table;
	private Rebindable!(const(Decl))[string] _shadow;
	const(Symbols) parent;
	const(int) level;
	@safe pure nothrow {
		const(Decl) lookup(string name) const {
			if (name is null)
				return null;
			if ((name in _shadow) !is null)
				return _shadow[name];
			if ((name in table) !is null)
				return table[name];
			if (parent !is null)
				return parent.lookup(name);
			else
				return null;
		}
		const(Decl) lookup_checked(string name) const {
			auto d = lookup(name);
			assert(d !is null, name~" is not defined");
			return d;
		}
		this(const(Symbols) p) {
			parent = p;
			if (p !is null)
				level = p.level+1;
			else
				level = 0;
		}
		string c_defs(StorageClass sc) const {
			string res = "";
			try {
				foreach(d; table) {
					auto vd = cast(const(VarDecl))d;
					if (vd is null)
						continue;
					if (vd.sc != sc)
						continue;
					res ~= vd.ty.c_type~" "~vd.symbol~";\n";
				}
			}catch(Exception e) {
				assert(false, e.msg);
			}
			return res;
		}
	}
	@safe nothrow {
		void insert(const(Decl) d) {
			assert((d.symbol in reserved_names) is null, "Reserved name "~d.symbol);
			assert(lookup(d.symbol) is null, "Duplicated name "~d.symbol);
			table[d.symbol] = d;
		}
		void shadow(const(Decl) d) {
			assert(lookup(d.symbol) !is null, "Cannot shadow a non-existent variable");
			assert((d.symbol in _shadow) is null, "Can't shadow twice "~d.symbol);
			if ((d.symbol in table) !is null)
				table[d.symbol] = d;
			_shadow[d.symbol] = d;
		}
		Shadows shadowed() const {
			return new Shadows(this);
		}
		void replace(Decl d) {
			assert((d.symbol in table) !is null);
			table[d.symbol] = d;
		}
		void merge_shadowed(Shadows sha) {
			foreach(d; sha)
				shadow(d);
		}
	}
}

immutable bool[string] reserved_names;

static this() {
	string[] ns = ["__current", "__next", "__event", "__p", "__tags"];
	foreach(n; ns)
		reserved_names[n] = true;
}
