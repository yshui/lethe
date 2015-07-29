module dioni.utils;
private template TupleHelper(T...) {
	alias TupleHelper = T;
}
template Iota(int S, int T) {
	static if (S >= T)
		alias Iota = TupleHelper!();
	else
		alias Iota = TupleHelper!(S, Iota!(S+1, T));
}
