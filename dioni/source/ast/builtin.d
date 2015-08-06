module ast.builtin;
import ast.type, ast.decl, ast.symbols;
import std.typetuple;
import mustache;
import error;
import std.exception : enforceEx;
private @safe :
template Builtin(string name, string tmpl, R, T...) if (is(R: TypeBase)){
	struct Builtin {
		import std.conv : to;
		enum symbol = name~to!string(T.length);
		static string c_call(string[] param, const(TypeBase)[] ty, out TypeBase retty) {
			retty = new R;
			string[] p;
			string first_p;
			auto ctx = new MustacheEngine!string.Context;
			//Check type match
			foreach(i, t; T) {
				auto code = ty[i].c_cast(new t, param[i]);
				static if (i == 0)
					first_p = code;
				else {
					auto sub = ctx.addSubContext("rest");
					sub["param"] = code;
				}
			}

			MustacheEngine!string r;
			ctx["name"] = name;
			ctx["retty"] = retty.c_type;
			ctx["first"] =first_p;
			return r.renderString(tmpl, ctx);
		}
	}
}

template UniqName(T...) {
	static if (T.length == 1) {
		static if (is(T[0] == Builtin!U, U...))
			alias UniqName = TypeTuple!(T[0].symbol);
		else
			static assert(false);
	} else static if (is(T[0] == Builtin!U1, U1...) &&
			is(T[1] == Builtin!U2, U2...)) {
		static if (T[0].symbol == T[1].symbol)
			alias UniqName = UniqName!(T[1..$]);
		else
			alias UniqName = TypeTuple!(T[0].symbol, UniqName!(T[1..$]));
	} else
		static assert(false);
}

template FilterByName(string name, T...) {
	static if (T.length == 0)
		alias FilterByName = TypeTuple!();
	else static if (is(T[0] == Builtin!U, U...)) {
		static if (name == T[0].symbol)
			alias FilterByName = TypeTuple!(T[0], FilterByName!(name, T[1..$]));
		else
			alias FilterByName = FilterByName!(name, T[1..$]);
	} else
		static assert(false);
}

alias builtins = TypeTuple!(
	Builtin!("vec", "{{=<% %>=}}((struct vec2){<%&first%><%#rest%>,<%&param%><%/rest%>})", Type!(float, 2), Type!float, Type!float),
	Builtin!("vec", "{{=<% %>=}}((struct vec3){<%&first%><%#rest%>,<%&param%><%/rest%>})", Type!(float, 3), Type!float, Type!float, Type!float),
	Builtin!("vec", "{{=<% %>=}}((struct vec3){<%&first%><%#rest%>,<%&param%><%/rest%>})", Type!(float, 4), Type!float, Type!float, Type!float, Type!float),
	Builtin!("cos", "cosf({{&first}})", Type!float, Type!float),
	Builtin!("sin", "sinf({{&first}})", Type!float, Type!float),
	Builtin!("tan", "tanf({{&first}})", Type!float, Type!float),
	Builtin!("asin", "asinf({{&first}})", Type!float, Type!float),
	Builtin!("acos", "acosf({{&first}})", Type!float, Type!float),
	Builtin!("atan", "atanf({{&first}})", Type!float, Type!float),
	Builtin!("rand", "rand_vec2({{&first}})", Type!(float, 2), RangeType!(float, 2)),
	Builtin!("rand", "rand_vec3({{&first}})", Type!(float, 3), RangeType!(float, 3)),
	Builtin!("rand", "rand_vec4({{&first}})", Type!(float, 4), RangeType!(float, 4)),
	Builtin!("rand", "rand_float({{&first}})", Type!float, RangeType!float),
	Builtin!("rand", "rand_int({{&first}})", Type!int, RangeType!int),
);

class BuiltinFn(B) : Callable {
override :
	string c_call(string[] pcode, const(TypeBase)[] ty, out TypeBase oty) const {
		return B.c_call(pcode, ty, oty);
	}
	string str() const {
		return "builtinFn "~B.stringof;
	}
	string symbol() const { return B.symbol; }
	string c_code(const(Symbols) s, bool prototype_only) const { return ""; }
}

public void initBuiltin(Symbols global) {
	alias all_names = UniqName!builtins;
	foreach(n; all_names) {
		auto o = new Overloaded(n);
		foreach(B; FilterByName!(n, builtins))
			o.insert(new BuiltinFn!B);
		global.insert(o);
	}
}
