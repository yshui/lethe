module ast.match;
import ast.expr;
class ParticleMatch {
	Var var;
	string particle;
	this(Var xv, string xp) {
		particle = xp;
		var = xv;
	}
}
