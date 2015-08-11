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
	struct BufferedReader {
		ubyte[] now;
		R i;
		bool empty() {
			return now.length != 0;
		}
		ubyte front() {
			return now[0];
		}
		void popFront() {
			now = now[1..$];
			if (now.length == 0 && !i.empty) {
				now = i.front();
				i.popFront();
			}
		}
	}
	if (i.empty)
		return BufferedReader([], i);

	auto tmp = i.front();
	i.popFront();
	return BufferedReader(tmp, i);
}
