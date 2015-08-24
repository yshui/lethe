module utils;
import std.range;
private template TupleHelper(T...) {
	alias TupleHelper = T;
}
template Iota(int S, int T) {
	static if (S >= T)
		alias Iota = TupleHelper!();
	else
		alias Iota = TupleHelper!(S, Iota!(S+1, T));
}

auto bufreader(R)(R i) if (isInputRange!R && is(ElementType!R == ubyte[])) {
	class BufferedReader {
		ubyte[] now;
		R i;
		this(R xi) {
			i = xi;
			if (!i.empty) {
				now = i.front();
				i.popFront();
			} else
				now = [];
		}
		bool empty() {
			return now.length == 0;
		}
		ubyte front() {
			return now[0];
		}
		void popFront() {
			import std.stdio;
			now = now[1..$];
			if (now.length == 0 && !i.empty) {
				now = i.front();
				i.popFront();
			}
		}
	}
	return new BufferedReader(i);
}

template venforce(E) {
	pure @safe T venforce(T, Args...)(T value, Args args) if (is(typeof(new E(args)))) {
		if (!value)
			throw new E(args);
		return value;
	}
}
