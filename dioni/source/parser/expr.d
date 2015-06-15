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
		choice!(parse_term, parse_paren),
		build_expr_tree,
		choice!(token_ws!"+", token_ws!"-")
	)(i);
}

auto parse_term(Stream i){
	return chain!(
		choice!(parse_number, parse_paren),
		build_expr_tree,
		choice!(token_ws!"*", token_ws!"/")
	)(i);
}

Expr build_expr_tree(Expr a, string op, Expr b) {
	return new BinOP(a, op, b);
}
