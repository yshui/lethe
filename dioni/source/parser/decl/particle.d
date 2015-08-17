module parser.decl.particle;
import ast.decl;
import parser.decl, parser.utils;
import sdpc;
import std.algorithm;
@safe :
auto parse_tagarr(Stream i) {
	auto r = seq!(
		optional!(token_ws!"-"),
		identifier
	)(i);
	r.r.name = "tag";
	if (!r.ok)
		return err_result!string(r.r);
	auto res = r.result!1;
	if (r.result!0 !is null)
		res = r.result!0~res;
	return ok_result(res, r.consumed, r.r);
}
auto parse_particle(Stream i) {
	auto r = seq!(
		token_ws!"particle",
		identifier,
		optional!(between!(token_ws!"[",
			chain!(parse_tagarr, arr_append!string, discard!(token_ws!",")),
			token_ws!"]")
		),
		optional!(seq!(
			discard!(token_ws!"<<"),
			chain!(identifier, arr_append!string, discard!(token_ws!","))
		)),
		between!(token_ws!"{", many!parse_decl, token_ws!"}")
	)(i);
	r.r.name = "particle";
	if (!r.ok)
		return err_result!Particle(r.r);

	auto decls = reduce!((a,b)=>a~b)(r.result!4);
	auto ret = new Particle(r.result!1, r.result!2, r.result!3, decls);
	return ok_result(ret, r.consumed, r.r);
}
