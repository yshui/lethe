module parser.particle;
import ast.particle;
import parser.decl, parser.utils;
import sdpc;
auto parse_particle(Stream i) {
	auto r = seq!(
		token_ws!"particle",
		identifier,
		optional!(seq!(
			discard!(token_ws!":"),
			identifier
		)),
		token_ws!"{",
		many!parse_decl,
		token_ws!"}"
	)(i);
	r.r.name = "particle";
	if (!r.ok)
		return err_result!Particle(r.r);

	auto ret = new Particle(r.result!1, r.result!2, r.result!4);
	return ok_result(ret, r.consumed, r.r);
}
