module parser.expr;
import sdpc;
import ast.expr;
import parser.atom, parser.utils;
import utils;
import std.conv: to;
import std.stdio;
@safe :
auto parse_range(Stream i) {
	auto r = seq!(
		parse_expr,
		discard!(token_ws!".."),
		parse_expr
	)(i);
	r.r.name = "range";
	if (!r.ok)
		return err_result!Range(r.r);
	return ok_result(new Range(r.result!0, r.result!1), r.consumed, r.r);
}

auto parse_random(Stream i) {
	auto r = seq!(
		discard!(token_ws!"$"),
		between!(token_ws!"(",
			parse_range,
		token_ws!")")
	)(i);
	r.r.name = "random";
	if (!r.ok)
		return err_result!Expr(r.r);
	return ok_result!Expr(new Random(r.result), r.consumed, r.r);
}

auto parse_paren(Stream i) {
	auto r = between!(token_ws!"(", parse_expr, token_ws!")")(i);
	r.r.name = "parentheses";
	return r;
}

auto parse_qmark(Stream i) {
	auto r = token_ws!"?"(i);
	r.r.name = "qmark";
	if (!r.ok)
		return err_result!Expr(r.r);

	auto res = new QMark;
	return ok_result!Expr(res, r.consumed, r.r);
}

auto parse_new(Stream i) {
	auto r = seq!(
		discard!(token_ws!"`"),
		identifier,
		optional!(between!(token_ws!"(",
			chain!(parse_expr, arr_append!Expr, discard!(token_ws!","), true),
		token_ws!")"))
	)(i);
	r.r.name = "new";

	if (!r.ok)
		return err_result!NewExpr(r.r);

	auto res = new NewExpr(r.result!0, r.result!1);
	return ok_result(res, r.consumed, r.r);
}

alias parse_new_expr = cast_result!(Expr, parse_new);

ParseResult!Expr parse_expr(Stream i) {
	auto r = chain!(
		parse_term,
		build_expr_tree,
		choice!(token_ws!"+", token_ws!"-")
	)(i);
	r.r.name = "expr";
	return r;
}

auto parse_term(Stream i){
	auto r = chain!(
		parse_primary,
		build_expr_tree,
		choice!(token_ws!"/", token_ws!"*:", token_ws!"*.", token_ws!"*")
	)(i);
	r.r.name = "term";
	return r;
}

ParseResult!Expr parse_primary(Stream i) {
	auto r = choice!(
		parse_number,
		parse_unop,
		parse_paren,
		parse_call,
		parse_field,
		parse_var_expr,
		parse_random
	)(i);
	r.r.name = "primary";
	return r;
}

auto parse_lvalue(Stream i) {
	auto r = choice!(parse_var)(i);
	r.r.name = "lvalue";
	return r;
}

auto parse_unop(Stream i) {
	auto r = seq!(
		choice!(token!"+", token!"-"),
		parse_primary,
	)(i);
	r.r.name = "unop";
	if (!r.ok)
		return err_result!Expr(r.r);
	return ok_result!Expr(new UnOP(r.result!0, r.result!1), r.consumed, r.r);
}

auto parse_call(Stream i) {
	auto r = seq!(
		id_ws,
		between!(token_ws!"(",
			chain!(parse_expr, arr_append!Expr, discard!(token_ws!",")),
		token_ws!")")
	)(i);
	r.r.name = "call";
	if (!r.ok)
		return err_result!Expr(r.r);
	return ok_result!Expr(new Call(r.result!0, r.result!1), r.consumed, r.r);
}

auto parse_field(Stream i) {
	alias field_left = choice!(
		parse_call,
		parse_var_expr,
		parse_paren,
		parse_unop,
		parse_random
	);
	auto r = seq!(
		field_left,
		discard!(token_ws!"."),
		chain!(identifier, arr_append!string, discard!(token_ws!"."))
	)(i);
	auto re = r.r;
	re.name = "field";
	if (!r.ok)
		return err_result!Expr(re);
	Expr ret = r.result!0;
	foreach(rhs; r.result!1)
		ret = new Field(ret, rhs);
	return ok_result!Expr(ret, r.consumed, re);
}
alias parse_range_expr = cast_result!(Expr, parse_range);
alias parse_expr_and_range = choice!(parse_range_expr, parse_expr);
auto parse_cmp(Stream i) {
	auto r = seq!(
		parse_expr,
		choice!(
			token_ws!"~",
			token_ws!"==",
			token_ws!"<=",
			token_ws!">=",
			token_ws!"<",
			token_ws!">",
			token_ws!"!="
		),
		parse_expr_and_range
	)(i);
	r.r.name = "cmp";
	if (!r.ok)
		return err_result!Expr(r.r);
	auto cmp = new Cmp(r.result!0, r.result!1, r.result!2);
	return ok_result!Expr(cmp, r.consumed, r.r);
}
auto parse_conj(Stream i) {
	auto r = chain!(
		parse_disj,
		build_bool_tree,
		token_ws!"||"
	)(i);
	return r;
}
auto parse_disj(Stream i) {
	auto r = chain!(
		parse_bool_primary,
		build_bool_tree,
		token_ws!"&&"
	)(i);
	return r;
}
auto parse_bool_paren(Stream i) {
	auto r = between!(
		token_ws!"(",
		parse_bool_primary,
		token_ws!")"
	)(i);
	return r;
}
ParseResult!Expr parse_bool_primary(Stream i) {
	auto r = choice!(
		parse_cmp,
		parse_bool_paren,
		parse_bool_neg,
	)(i);
	return r;
}
auto parse_bool_neg(Stream i) {
	auto r = seq!(discard!(token_ws!"!"), parse_bool_paren)(i);
	r.r.name = "bool neg";
	if (!r.ok)
		return err_result!Expr(r.r);
	return ok_result!Expr(new UnOP("!", r.result), r.consumed, r.r);
}

alias parse_bool_expr = parse_conj;

Expr build_expr_tree(Expr a, string op, Expr b) {
	return new BinOP(a, op, b);
}
Expr build_expr_tree(Expr a) {
	return a;
}
Expr build_bool_tree(Expr a, string op, Expr b) {
	return new BoolOP(a, op, b);
}
Expr build_bool_tree(Expr a) {
	return a;
}
