module parser.atom;
import sdpc;
import ast.expr;
import std.conv,
       std.stdio;

auto parse_number_nows(Stream i) {
	auto parse_exp_str(Stream i) {
		auto r = seq!(
			token!"e",
			optional!(choice!(token!"+", token!"-")),
			word!digits,
		)(i);
		auto re = r.r;
		re.name = "exp";
		if (!r.ok)
			return ok_result!string("", 0, re);
		string exp = r.result!2;
		if (r.result!1 !is null)
			exp = r.result!1 ~ exp;
		return ok_result!string("e"~exp, r.consumed, re);
	}
	auto parse_fraction_str(Stream i) {
		auto r = seq!(
			lookahead!(token!".", token!".", true),
			optional!(word!digits)
		)(i);
		auto re = r.r;
		re.name = "fraction";

		if (!r.ok)
			return ok_result!string("", 0, re);

		string k = "";
		if (r.result!1 !is null)
			k = r.result!1;
		return ok_result!string(k, r.consumed, re);
	}
	auto r = seq!(
		word!digits,
		parse_fraction_str,
		parse_exp_str,
	)(i);
	auto re = r.r;
	re.name = "number";
	if (!r.ok)
		return err_result!Expr(re);

	if (r.result!1 == "" && r.result!2 == "") {
		//This is a int
		//writeln("Matched int" ~ r.result!0);
		return ok_result!Expr(new Num(to!int(r.result!0)), r.consumed, re);
	}

	string float_string = r.result!0 ~ "." ~ r.result!1 ~ r.result!2;
	//writeln("Matched float" ~ float_string);
	return ok_result!Expr(new Num(to!float(float_string)), r.consumed, re);
}

auto parse_var_nows(Stream i) {
	auto r = identifier(i);
	r.r.name = "variable";
	if (!r.ok)
		return err_result!LValue(r.r);
	//writeln("Matched var " ~ r.result);

	return ok_result!LValue(new Var(r.result), r.consumed, r.r);
}

auto parse_number(Stream i) {
	auto r = between!(skip_whitespace, parse_number_nows, skip_whitespace)(i);
	r.r.promote();
	return r;
}
auto parse_var(Stream i) {
	auto r = between!(skip_whitespace, parse_var_nows, skip_whitespace)(i);
	r.r.promote();
	return r;
}
alias parse_var_expr = cast_result!(Expr, parse_var);
