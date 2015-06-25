module parser.utils;
import sdpc;
auto token_ws(string t)(Stream i) {
	auto r = between!(skip_whitespace, token!t, skip_whitespace)(i);
	r.r.promote();
	return r;
}
T[] arr_append(T)(T[] a, T[] b) {
	a ~= b;
	return a;
}
