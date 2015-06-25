module sdpc.combinators.combinators;
import sdpc.primitives;
import std.traits,
       std.string,
       std.stdio,
       std.typetuple;

///Match pattern `begin func end`, return the result of func.
auto between(alias begin, alias func, alias end)(Stream i) {
	alias RetTy = ReturnType!func;
	alias ElemTy = ElemType!RetTy;
	static assert(is(RetTy == ParseResult!U, U));
	i.push();
	auto begin_ret = begin(i);
	size_t consumed = begin_ret.consumed;
	if (begin_ret.s != Result.OK)
		return err_result!ElemTy();
	auto ret = func(i);
	if (ret.s != Result.OK) {
		i.pop();
		return ret;
	}
	consumed += ret.consumed;
	auto end_ret = end(i);
	if (end_ret.s != Result.OK) {
		i.pop();
		return err_result!ElemTy();
	}
	ret.consumed = end_ret.consumed+consumed;
	return ret;
}

///Match any of the given pattern, stop when first match is found. All parsers
///must return the same type.
auto choice(T...)(Stream i) {
	alias ElemTy = ElemType!(ReturnType!(T[0]));
	foreach(p; T) {
		writeln("Trying " ~ __traits(identifier, p));
		auto ret = p(i);
		if (ret.s == Result.OK)
			return ret;
	}
	return err_result!ElemTy();
}

/**
  Match pattern `p delim p delim p ... p delim p`

  Return the result of left-associative applying `op` on the result of `p`
*/
auto chain(alias p, alias op, alias delim)(Stream i) {
	auto ret = p(i);
//	alias ElemTy = ReturnType!op;
	if (ret.s != Result.OK)
		return ret;
	auto res = ret.result;
	auto consumed = ret.consumed;

	while(true) {
		i.push();
		auto dret = delim(i);
		if (dret.s != Result.OK)
			break;
		auto pret = p(i);
		if (pret.s != Result.OK) {
			i.pop();
			return ok_result(res, consumed);
		}
		static if (is(ReturnType!delim == ParseResult!void))
			res = op(res, pret.result);
		else
			res = op(res, dret.result, pret.result);
		ret = pret;
		consumed += dret.consumed+pret.consumed;
		i.drop();
	}
	return ok_result(res, consumed);
}

/**
  Match `func*` or `func+`

  Return array of func's result
*/
auto many(alias func, bool allow_none = false)(Stream i) {
	alias ElemTy = ElemType!(ReturnType!func);
	static if (is(ElemTy == void)) {
		alias ARetTy = ParseResult!void;
		size_t count = 0;
	} else {
		alias ARetTy = ParseResult!(ElemTy[]);
		ElemTy[] res;
	}
	size_t consumed = 0;
	while(true) {
		auto ret = func(i);
		if (ret.s != Result.OK) {
			static if (is(ElemTy == void))
				return ARetTy((count || allow_none) ?
				               Result.OK : Result.Err, consumed);
			else
				return ARetTy((res.length || allow_none) ?
				              Result.OK : Result.Err, consumed, res);
		}
		consumed += ret.consumed;
		static if (!is(ElemTy == void))
			res ~= [ret];
		else
			count++;
	}
}

///Consumes nothing, always return OK
auto nop(Stream i) {
	return ParseResult!void(Result.OK, 0);
}

private class ParserID(alias func, int id) { }

private template genParserID(int start, T...) {
	static if (T.length == 0)
		alias genParserID = TypeTuple!();
	else {
		private alias now = ParserID!(T[0], start);
		static if (is(ReturnType!(T[0]) == ParseResult!void))
			private enum int next = start;
		else
			private enum int next = start+1;
		alias genParserID = TypeTuple!(now, genParserID!(next, T[1..$]));
	}
}

/**
  Matching using a sequence of parsers, beware that result can only be
  indexed with number readable at compile time, like this: `ret.resutl!0`.

  Also none of the parsers used in seq can return a tuple of results. Otherwise
  it won't compile.
*/
auto seq(T...)(Stream i) {
	alias ElemTys = ElemTypesNoVoid!(staticMap!(ReturnType, T));
	alias RetTy = ParseResult!ElemTys;
	alias PID = genParserID!(0, T);
	ElemTys res = void;
	size_t consumed = 0;
	i.push();
	foreach(pid; PID) {
		static if (is(pid == ParserID!(p, id), alias p, int id)) {
			auto ret = p(i);
			consumed += ret.consumed;
			if (ret.s != Result.OK) {
				writeln("Matching " ~ __traits(identifier, p) ~ " failed, rewind ", consumed);
				i.pop();
				static if (ElemTys.length == 1)
					return err_result!(ElemTys[0])();
				else
					return RetTy(Result.Err, 0, ElemTys.init);
			}
			static if (!is(typeof(ret) == ParseResult!void))
				res[id] = ret.result;
		} else
			static assert(false, p);
	}
	static if (ElemTys.length == 1)
		return ok_result!(ElemTys[0])(res[0], consumed);
	else
		return RetTy(Result.OK, consumed, res);
}

auto seq2(alias op, T...)(Stream i) {
	auto r = seq!T(i);
	if (!r.ok)
		return err_result!(ReturnType!op)();
	alias ElemTy = ElemType!(typeof(r));
	auto ret = op(r.result!0);
	foreach(id, e; ElemTy[1..$])
		ret = op(ret, r.result!(id+1));
	return ok_result(ret, r.consumed);
}

///optionally matches p.
auto optional(alias p)(Stream i) {
	auto r = p(i);
	r.s = Result.OK;
	return r;
}

///lookahead
auto lookahead(alias p, alias u, bool negative = false)(Stream i) {
	i.push();

	auto r = p(i);
	alias RetTy = typeof(r);
	alias ElemTy = ElemType!RetTy;
	if (!r.ok)
		return r;

	i.push();
	auto r2 = u(i);
	i.pop();

	bool pass = r2.ok;

	static if (negative)
		pass = !pass;

	if (!pass) {
		i.pop();
		return err_result!ElemTy();
	}
	return r;
}

///This combinator first try to match u without consuming anything,
///and continue only if u matches (or not, if negative == true).
auto when(alias u, alias p, bool negative = false)(Stream i) {
	alias RetTy = ReturnType!p;
	alias ElemTy = ElemType!RetTy;
	i.push();
	auto r = u(i);
	i.pop();

	static if (negative) {
		if (r.ok)
			return err_result!ElemTy();
	} else {
		if (!r.ok)
			return err_result!ElemTy();
	}

	auto r2 = p(i);
	return r;
}

///Match a string, return the matched string
ParseResult!string token(string t)(Stream i) {
	if (!i.starts_with(t))
		return err_result!string();
	string ret = i.advance(t.length);
	return ok_result!string(ret, t.length);
}

///Skip `p` zero or more times
ParseResult!void skip(alias p)(Stream i) {
	auto r = many!(p, true)(i);
	return ParseResult!void(Result.OK, r.consumed);
}

///Match 'p' but discard the result
ParseResult!void discard(alias p)(Stream i) {
	auto r = p(i);
	if (!r.ok)
		return err_result!void();
	return ParseResult!void(Result.OK, r.consumed);
}

///
unittest {
	import std.stdio;
	import std.array;
	import std.conv;
	BufStream i = new BufStream("(asdf)");
	auto r = between!(token!"(", token!"asdf", token!")")(i);
	assert(r.ok);
	assert(i.eof());

	i = new BufStream("abcdaaddcc");
	alias abcdparser = many!(choice!(token!"a", token!"b", token!"c", token!"d"));
	auto r2 = abcdparser(i);
	assert(r2.ok);
	assert(i.eof());

	i = new BufStream("abcde");
	i.push();
	auto r3 = abcdparser(i);
	assert(r3.ok); //Parse is OK because 4 char are consumed
	assert(!i.eof()); //But the end-of-buffer is not reached

	i.revert();
	auto r4 = seq!(token!"a", token!"b", token!"c", token!"d", token!"e")(i);
	assert(r4.ok);
	assert(r4.result!0 == "a");
	assert(r4.result!1 == "b");
	assert(r4.result!2 == "c");
	assert(r4.result!3 == "d");
	assert(r4.result!4 == "e");

	i.revert();
	auto r5 = seq!(token!"a")(i); //test seq with single argument.
	assert(r5.ok, to!string(r5.s));
	assert(r5.result == "a");

	i.revert();
	auto r7 = seq2!(function (string a, string b = "") { return a ~ b; },
			token!"a", token!"b")(i); //test seq with single argument.
	assert(r7.ok);
	assert(r7.result == "ab");

	i.revert();
	auto r6 = optional!(token!"x")(i);
	assert(r6.ok);
	assert(r6.t is null);
}
