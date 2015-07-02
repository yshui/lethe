module parser.utils;
import sdpc;
auto token_ws(string t)(Stream i) {
	auto r = between!(skip_whitespace, token!t, skip_whitespace)(i);
	r.r.promote();
	return r;
}

template arr_append(T) {
	T[] arr_append(T[] a, T[] b) {
		a ~= b;
		return a;
	}

	T[] arr_append(T[] a, T b) {
		a ~= b;
		return a;
	}
	T[] arr_append(T a, T b) {
		return [a, b];
	}
	T[] arr_append(T a) {
		return [a];
	}
	T[] arr_append(T[] a) {
		return a;
	}
	T[] arr_append() {
		return [];
	}
}
