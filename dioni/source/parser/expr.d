module parser.expr;
import sdpc;
import ast.expr;
import parser.atom, parser.utils;
import dioni.utils;
import std.conv: to;
import std.stdio;

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

auto parse_new_particle(Stream i) {
	auto r = seq!(
		discard!(token_ws!"`"),
		identifier,
		optional!(between!(token_ws!"(",
			chain!(parse_expr, arr_append!Expr, discard!(token_ws!","), true),
		token_ws!")"))
	)(i);
	r.r.name = "new particle";

	if (!r.ok)
		return err_result!NewParticle(r.r);

	auto res = new NewParticle(r.result!0, r.result!1);
	return ok_result(res, r.consumed, r.r);
}

alias parse_new_particle_expr = cast_result!(Expr, parse_new_particle);

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
		choice!(token_ws!"*", token_ws!"/")
	)(i);
	r.r.name = "term";
	return r;
}

ParseResult!Expr parse_primary(Stream i) {
	auto r = choice!(
		parse_number,
		parse_unop,
		parse_paren,
		parse_vec,
		parse_field_expr,
		parse_var_expr
	)(i);
	r.r.name = "primary";
	return r;
}

auto parse_lvalue(Stream i) {
	auto r = choice!(parse_field, parse_var)(i);
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
	auto re = r.r;
	re.name = "vec";
	if (!r.ok)
		return err_result!Expr(re);
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
	return ok_result!Expr(a, r.consumed, re);
}

auto parse_field(Stream i) {
	auto r = seq!(
		identifier,
		token_ws!".",
		identifier
	)(i);
	auto re = r.r;
	re.name = "field";
	if (!r.ok)
		return err_result!LValue(re);
	return ok_result!LValue(new Field(r.result!0, r.result!2), r.consumed, re);
}

alias parse_field_expr = cast_result!(Expr, parse_field);

Expr build_expr_tree(Expr a, string op, Expr b) {
	return new BinOP(a, op, b);
}
Expr build_expr_tree(Expr a) {
	return a;
}
