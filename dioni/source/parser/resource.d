module parser.resource;
import parser.utils;
import sdpc;

auto parse_import(Stream i) {
	auto r = seq!(
		discard!(token_ws!"import"),
		parse_string,
		optional!(
			discard!(token_ws!"as"),
			identifier,
		),
		discard!(token_ws!";")
	)(i);

}
