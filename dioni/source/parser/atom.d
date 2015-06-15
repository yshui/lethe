module parser.atom;
import sdpc;
import ast;

auto parse_number_nows(Stream i) {
	auto r =  number(i);
	if (r.s != State.OK)
		return ParseResult!Expr(State.Err, 0, null);
	auto e = new Num(r);
	return ParseResult!Expr(State.OK, r.consumed, e);
}

auto parse_float_nows(Stream i) {

}

alias parse_number = between!(skip_whitespace, parse_number_nows, skip_whitespace);

auto parse_variable(Stream i) {

}
