module ast.aggregator;
import ast.type;

abstract class Aggregator : TypeBase {
	string c_aggregate(Var v, Expr e, const(Symbols) s) { assert(false); }
	string c_clear(Var v, const(Symbols) s) { assert(false); }
	string c_foreach(Var v, Var loop, Stmt[] bdy, const(Symbols) s) {
		assert(false);
	}
}

class GlobalParticleAggregator : Aggregator {

override :
	string c_aggregate(Var v, Expr e, const(Symbols) s) const {
		auto vv = cast(Var)e;
		assert(vv !is null, "Only events is allowed to be sent to global");
		//TODO parse event expr
		assert(false);
	}
}
