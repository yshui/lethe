module parser.decl.vertex;
import sdpc;
import parser.decl, parser.utils;
import ast.decl;
@safe :

auto parse_vertex(Stream i) {
	auto r = seq!(
		discard!(token_ws!"vertex"),
		identifier,
		between!(token_ws!"(",
			chain!(parse_var_decl, arr_append!Var, discard!(token_ws!",")),
		token_ws!")"),
		discard!(token_ws!";")
	)(i);
	if (!r.ok)
		return err_result!(Decl[])(r.r);
	return ok_result!(Decl[])([new Vertex(r.result!0, r.result!1)], r.consumed, r.r);
}
