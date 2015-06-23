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
		if (r.s == State.Err)
			return ParseResult!string(State.OK, 0, "");
		string exp = r.result!2;
		if (r.result!1 !is null)
			exp = r.result!1 ~ exp;
		return ParseResult!string(State.OK, r.consumed, "e" ~ exp);
	}
	auto parse_fraction_str(Stream i) {
		auto r = seq!(
			lookahead!(token!".", token!".", true),
			optional!(word!digits)
		)(i);

		if (r.s == State.Err)
			return ParseResult!string(State.OK, 0, "");

		string k = "";
		if (r.result!1 !is null)
			k = r.result!1;
		return ParseResult!string(State.OK, r.consumed, k);
	}
	auto r = seq!(
		word!digits,
		parse_fraction_str,
		parse_exp_str,
	)(i);
	if (r.s == State.Err)
		return ParseResult!Expr(State.Err, 0, null);

	if (r.result!1 == "" && r.result!2 == "") {
		//This is a int
		writeln("Matched int" ~ r.result!0);
		return ParseResult!Expr(State.OK, r.consumed, new Num(to!int(r.result!0)));
	}

	string float_string = r.result!0 ~ "." ~ r.result!1 ~ r.result!2;
	writeln("Matched float" ~ float_string);
	return ParseResult!Expr(State.OK, r.consumed, new Num(to!float(float_string)));
}

auto parse_var_nows(Stream i) {
	auto r = identifier(i);
	if (!r.ok)
		return err_result!LValue();
	writeln("Matched var " ~ r.result);

	return ok_result!LValue(new Var(r.result), r.consumed);
}

alias parse_number = between!(skip_whitespace, parse_number_nows, skip_whitespace);
alias parse_var = between!(skip_whitespace, parse_var_nows, skip_whitespace);
alias parse_var_expr = cast_result!(Expr, parse_var);
