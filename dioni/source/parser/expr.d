module parser.expr;
import sdpc;
import ast;
import parser.atom;

template token_ws(string t) {
	alias token_ws = between!(skip_whitespace, token!t, skip_whitespace);
}

auto parse_paren(Stream i) {
	return between!(token_ws!"(", parse_expr, token_ws!")")(i);
}

ParseResult!Expr parse_expr(Stream i) {
	return chain!(
		parse_term,
		build_expr_tree,
		choice!(token_ws!"+", token_ws!"-")
	)(i);
}

auto parse_term(Stream i){
	return chain!(
		parse_primary,
		build_expr_tree,
		choice!(token_ws!"*", token_ws!"/")
	)(i);
}

ParseResult!Expr parse_primary(Stream i) {
	return choice!(
		parse_number,
		parse_unop,
		parse_paren,
		parse_var,
	)(i);
}

auto parse_unop(Stream i) {
	auto r = seq!(
		choice!(token!"+", token!"-"),
		parse_primary,
	)(i);
	if(!r.ok)
		return ParseResult!Expr(State.Err, 0, null);
	return ParseResult!Expr(State.OK, r.consumed, new UnOP(r.result!0, r.result!1));
}

Expr build_expr_tree(Expr a, string op, Expr b) {
	return new BinOP(a, op, b);
}
