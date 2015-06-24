module parser.expr;
import sdpc;
import ast.expr;
import parser.atom, parser.utils;
import dioni.utils;
import std.conv: to;
import std.stdio;

auto parse_paren(Stream i) {
	return between!(token_ws!"(", parse_expr, token_ws!")")(i);
}

ParseResult!Expr parse_expr(Stream i) {
	auto r = chain!(
		parse_term,
		build_expr_tree,
		choice!(token_ws!"+", token_ws!"-")
	)(i);
	if (r.ok)
		writeln("Matched expr");
	return r;
}

auto parse_term(Stream i){
	return chain!(
		parse_primary,
		build_expr_tree,
		choice!(token_ws!"*", token_ws!"/")
	)(i);
}

ParseResult!Expr parse_primary(Stream i) {
	writeln("primary");
	auto r = choice!(
		parse_number,
		parse_unop,
		parse_paren,
		parse_vec,
		parse_field_expr,
		parse_var_expr
	)(i);
	if (r.ok)
		writeln("Matched primary");
	return r;
}

alias parse_lvalue = choice!(parse_field, parse_var);

auto parse_unop(Stream i) {
	auto r = seq!(
		choice!(token!"+", token!"-"),
		parse_primary,
	)(i);
	if (!r.ok)
		return err_result!Expr();
	return ok_result!Expr(new UnOP(r.result!0, r.result!1), r.consumed);
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

auto parse_field(Stream i) {
	auto r = seq!(
		identifier,
		token_ws!".",
		identifier
	)(i);
	if (!r.ok)
		return err_result!LValue();
	return ok_result!LValue(new Field(r.result!0, r.result!2), r.consumed);
}

alias parse_field_expr = cast_result!(Expr, parse_field);

Expr build_expr_tree(Expr a, string op, Expr b) {
	return new BinOP(a, op, b);
}
