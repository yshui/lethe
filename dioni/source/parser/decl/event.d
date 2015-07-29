module parser.decl.event;
import parser.decl, parser.utils;
import sdpc;
import ast.expr, ast.decl, ast.type;
@safe :
auto parse_type2(Stream i) {
	auto r = choice!(
		token_ws!"particle"
	)(i);
	r.r.name = "type2";
	if (!r.ok)
		return err_result!TypeBase(r.r);

	return ok_result!TypeBase(new ParticleHandle, r.consumed, r.r);
}
auto parse_member_type(Stream i) {
	auto r = choice!(
		parse_type,
		parse_type2
	)(i);
	r.r.name = "event member type";
	return r;
}
auto parse_event(Stream i) {
	auto r = seq!(
		discard!(token_ws!"event"),
		identifier,
		between!(token_ws!"(",
		chain!(parse_member_type, arr_append!TypeBase, discard!(token_ws!",")),
		token_ws!")"),
		token_ws!";"
	)(i);
	r.r.name = "event definition";
	if (!r.ok)
		return err_result!Decl(r.r);
	return ok_result!Decl(new Event(r.result!0, r.result!1), r.consumed, r.r);
}

