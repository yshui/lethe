module ast.aggregator;
import ast.type, ast.expr, ast.symbols, ast.stmt;

abstract class Aggregator : TypeBase {
	string c_aggregate(Var v, Expr e, const(Symbols) s) const { assert(false); }
	string c_clear(Var v, const(Symbols) s) const { assert(false); }
	string c_foreach(Var v, Var loop, Stmt[] bdy, const(Symbols) s) const {
		assert(false);
	}
}

class GlobalParticleAggregator : Aggregator {

override :
	string c_aggregate(Var v, Expr e, const(Symbols) s) const {
		auto vv = cast(NewExpr)e;
		assert(vv !is null, "Only events is allowed to be sent to global");
		TypeBase ety;
		auto ecode = vv.c_code(s, ety);
		assert(typeid(ety) == typeid(EventType), vv.name~" is not an event");
		return "";
	}
}
