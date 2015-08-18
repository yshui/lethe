module parser.resource;
import parser.utils;
import sdpc;
import resource;
import ast.decl;

alias parse_string_ws = between!(skip_whitespace, parse_string, skip_whitespace);
@safe :
auto parse_import(Stream i) {
	auto r = seq!(
		discard!(token_ws!"import"),
		parse_string_ws,
		optional!(seq!(
			discard!(token_ws!"as"),
			identifier,
		)),
		discard!(token_ws!";")
	)(i);
	r.r.name = "import";
	if (!r.ok)
		return err_result!(Decl[])(r.r);
	return ok_result(load_resource(r.result!0, r.result!1), r.consumed, r.r);
}
