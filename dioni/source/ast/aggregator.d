module ast.aggregator;
import ast.type, ast.expr, ast.symbols, ast.stmt, ast.decl;

abstract class Aggregator : TypeBase {
	nothrow @safe {
		string c_aggregate(const(Decl) v, const(Expr) e,
				const(Symbols) s) const {
			assert(false);
		}
		pure {
			string c_assign(const(Decl) v, const(Expr) e,
					const(Symbols) s, bool delayed) const {
				assert(false);
			}
			string c_clear(const(Decl) v, const(Symbols) s) const {
				assert(false);
			}
			string c_foreach(const(Decl) v, const(VarDecl) loop,
					const(Stmt)[] bdy, const(Symbols) s) const {
				assert(false);
			}
		}
	}
}

class EventAggregator : Aggregator {

override :
	string c_aggregate(const(Decl) v, const(Expr) e, const(Symbols) s) const {
		auto vv = cast(const(NewExpr))e;
		assert(vv !is null, "Only events is allowed to be sent to global");
		TypeBase ety;
		auto ecode = vv.c_code(s, ety);
		assert(ety.type_match!EventType, vv.name~" is not an event");
		if (v.symbol == "global")
			return "queue_global_event("~ecode~");\n";
		else {
			auto td = cast(const(Tag))v;
			if (td !is null)
				return "queue_tag_event(TAG_"~td.name~", "~ecode~");\n";
		}
		assert(false);
	}
}
