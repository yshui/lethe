module ast.match;
import ast.expr;
class ParticleMatch {
	VarVal var;
	string particle;
	@safe this(VarVal xv, string xp) {
		particle = xp;
		var = xv;
	}
	pure nothrow @safe string str() const {
		return particle~"("~var.str~")";
	}
}
