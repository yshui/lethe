module parser.resource;
import parser.utils;
import sdpc;
import resource;

alias parse_string_ws = between!(skip_whitespace, parse_string, skip_whitespace);

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
	return load_resource(r.result!0, r.result!1);
}
