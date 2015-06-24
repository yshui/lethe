module parser.utils;
import sdpc;
template token_ws(string t) {
	alias token_ws = between!(skip_whitespace, token!t, skip_whitespace);
}
T[] arr_append(T)(T[] a, T[] b) {
	a ~= b;
	return a;
}
