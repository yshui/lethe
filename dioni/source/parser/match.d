module parser.match;
import sdpc;
import parser.utils;
import ast.match, ast.expr;
auto parse_particle_match(Stream i) {
	auto r = seq!(
		identifier,
		between!(token_ws!"(", identifier, token_ws!")")
	)(i);
	r.r.name = "particle match";
	if (!r.ok)
		return err_result!ParticleMatch(r.r);
	auto pm = new ParticleMatch(new Var(r.result!1), r.result!0);
	return ok_result(pm, r.consumed, r.r);
}
