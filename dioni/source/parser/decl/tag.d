module parser.decl.tag;
import parser.utils;
import ast.decl;
import sdpc;
auto parse_tag_name(Stream i) {
	auto r = identifier(i);
	r.r.name = "tag def";
	if (!r.ok)
		return err_result!Decl(r.r);
	return ok_result!Decl(new TagDecl(r.result), r.consumed, r.r);
}

auto parse_tag_decl(Stream i) {
	auto r = seq!(
		discard!(token_ws!"tag"),
		chain!(parse_tag_name, arr_append!Decl, discard!(token_ws!",")),
		discard!(token_ws!";")
	)(i);
	r.r.name = "tag decl";
	return r;
}
