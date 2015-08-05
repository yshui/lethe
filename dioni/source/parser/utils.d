module parser.utils;
import sdpc;
alias token_ws(string t) = between!(skip_whitespace, token!t, skip_whitespace);
alias id_ws = between!(skip_whitespace, identifier, skip_whitespace);

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
