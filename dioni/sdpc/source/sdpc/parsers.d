module sdpc.parsers;
import sdpc.combinators,
       sdpc.primitives;
import std.traits,
       std.string,
       std.conv;

///Match a single character, return func(indexOf, character)
auto ch(alias accept, alias func)(Stream i) {
	alias ElemTy = ReturnType!func;
	alias RetTy = ParseResult!ElemTy;
	auto re = Reason(i, "char");
	if (i.eof()) {
		re.msg = "EOF";
		return RetTy(Result.Err, 0, re, ElemTy.init);
	}
	char n = i.head[0];
	auto digi = accept.indexOf(n);
	if (digi < 0) {
		re.msg = "Unexpected " ~ n;
		return RetTy(Result.Err, 0, re, ElemTy.init);
	}
	i.advance(1);
	return RetTy(Result.OK, 1, re, func(digi, n));
}

template digit(alias _digits = digits) {
	private int conv(long id, char ch) { return cast(int)id; }
	alias digit = ch!(_digits, conv);
}

int digit_concat(int base = 10)(int a, int b) {
	return a*base+b;
}

immutable string lower = "qwertyuiopasdfghjklzxcvbnm";
immutable string upper = "QWERTYUIOPASDFGHJKLZXCVBNM";
immutable string alphabet = lower ~ upper;
immutable string digits = "0123456789";

template number(alias accept = digits, int base = 10)
if (accept.length == base) {
	alias number = chain!(digit!accept, digit_concat!base, nop);
}

template letter(alias accept = alphabet){
	private char conv(long id, char ch) { return ch; }
	alias letter = ch!(accept, conv);
}

template word(alias accept = alphabet){
	private string conv(long id, char ch) {
		return to!string(ch);
	}
	private alias letter = ch!(accept, conv);
	alias word = chain!(letter, str_concat, nop);
}

auto identifier(Stream i) {
	alias RetTy = ParseResult!string;
	auto ret = letter!(alphabet~"_")(i);
	auto re = ret.r;
	re.name = "identifier";
	if (ret.s != Result.OK)
		return RetTy(Result.Err, 0, re, null);
	string str = to!string(ret.result);
	auto ret2 = word!(alphabet~"_"~digits)(i);
	if (ret2.s == Result.OK)
		str ~= ret2;
	return RetTy(Result.OK, ret.consumed+ret2.consumed, re, str);
}

alias skip_whitespace = skip!(choice!(token!" ", token!"\n", token!"\t"));

string str_concat(string a, string b="") {
	return a ~ b;
}

unittest {
	import std.array;
	import std.stdio;
	auto i = new BufStream("12354");
	auto r = number(i);
	assert(r.ok);
	assert(r == 12354, to!string(r));

	i = new BufStream("ffabc");
	auto r3 = number!(digits~"abcdef", 16)(i);
	assert(r3.ok);
	assert(r3 == 1047228, to!string(r3));

	i = new BufStream("_asd1234a");
	auto r2 = identifier(i);
	assert(r2.ok);
	assert(i.eof());
	assert(r2 == "_asd1234a");
}
