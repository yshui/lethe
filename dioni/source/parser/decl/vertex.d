module parser.decl.vertex;
import sdpc;
import parser.decl, parser.utils;
import ast.decl;
@safe :
auto parse_vmember(Stream i) {
	auto r = seq!(
		parse_type,
		identifier
	)(i);
	if (!r.ok)
		return err_result!Var(r.r);
	return ok_result(new Var(r.result!0, null, r.result!1), r.consumed, r.r);
}

auto parse_vertex(Stream i) {
	auto r = seq!(
		discard!(token_ws!"vertex"),
		identifier,
		between!(token_ws!"(",
			chain!(parse_vmember, arr_append!Var, discard!(token_ws!",")),
		token_ws!")"),
		discard!(token_ws!";")
	)(i);
	if (!r.ok)
		return err_result!Decl(r.r);
	return ok_result!Decl(new Vertex(r.result!0, r.result!1), r.consumed, r.r);
}
