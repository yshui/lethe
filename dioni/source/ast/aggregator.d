module ast.aggregator;
import ast.type, ast.expr, ast.symbols, ast.stmt, ast.decl;

abstract class Aggregator : TypeBase {
	nothrow @safe {
		string c_aggregate(const(VarDecl) v, const(Expr) e,
				const(Symbols) s) const {
			assert(false);
		}
		pure {
			string c_assign(const(VarDecl) v, const(Expr) e,
					const(Symbols) s, bool delayed) const {
				assert(false);
			}
			string c_clear(const(VarDecl) v, const(Symbols) s) const {
				assert(false);
			}
			string c_foreach(const(VarDecl) v, const(VarDecl) loop,
					const(Stmt)[] bdy, const(Symbols) s) const {
				assert(false);
			}
		}
	}
}

class GlobalParticleAggregator : Aggregator {

override :
	string c_aggregate(const(VarDecl) v, const(Expr) e, const(Symbols) s) const {
		auto vv = cast(const(NewExpr))e;
		assert(vv !is null, "Only events is allowed to be sent to global");
		TypeBase ety;
		auto ecode = vv.c_code(s, ety);
		assert(ety.type_match!EventType, vv.name~" is not an event");
		return "";
	}
}
