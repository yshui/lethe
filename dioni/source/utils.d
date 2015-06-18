module dioni.utils;
private template TupleHelper(T...) {
	alias TupleHelper = T;
}
template StaticRange(int S, int T) {
	static if (S >= T)
		alias StaticRange = TupleHelper!();
	else {
		enum N = S+1;
		alias StaticRange = TupleHelper!(S, StaticRange!(N, T));
	}
}
