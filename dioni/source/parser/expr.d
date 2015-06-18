module parser.expr;
import sdpc;
import ast.expr;
import parser.atom;
import dioni.utils;
import std.conv: to;

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
		parse_vec,
		parse_var_expr,
		parse_index_expr,
	)(i);
}

ParseResult!LValue parse_lvalue_no_index(Stream i) {
	auto r = parse_var(i);
	if (!r.ok)
		return err_result!LValue();
	return ok_result!LValue(cast(LValue)r.result, r.consumed);
}

ParseResult!LValue parse_lvalue(Stream i) {
	return choice!(
		parse_var,
		parse_index
	)(i);
}

auto parse_unop(Stream i) {
	auto r = seq!(
		choice!(token!"+", token!"-"),
		parse_primary,
	)(i);
	if (!r.ok)
		return ParseResult!Expr(State.Err, 0, null);
	return ParseResult!Expr(State.OK, r.consumed, new UnOP(r.result!0, r.result!1));
}

auto parse_vec(Stream i) {
	auto r = seq!(
		skip_whitespace,
		token!"vec",
		choice!(token!"2", token!"3", token!"4"),
		token_ws!"(",
		parse_expr,
		token_ws!",",
		parse_expr,
		token_ws!")"
	)(i);
	if (!r.ok)
		return err_result!Expr();
	Expr a = null;
	int d = to!int(r.result!1);
Ld:     switch(d) {
		foreach(di; StaticRange!(2, 5)) {
			case di:
				a = new Vec!di([r.result!3, r.result!5]);
				break Ld;
		}
		default:
			assert(0);
	}
	import std.stdio: writeln;
	return ok_result!Expr(a, r.consumed);
}

auto parse_index(Stream i) {
	auto r = seq!(
		parse_lvalue_no_index,
		token_ws!"[",
		parse_expr,
		token_ws!"]",
	)(i);
	if (!r.ok)
		return err_result!LValue();

	return ok_result!LValue(new Index(r.result!0, r.result!2), r.consumed);
}

alias parse_index_expr = cast_result!(Expr, parse_index);

Expr build_expr_tree(Expr a, string op, Expr b) {
	return new BinOP(a, op, b);
}
