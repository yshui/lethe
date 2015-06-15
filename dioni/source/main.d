import std.stdio;
import parser;
import sdpc;
void main() {
	while(!stdin.eof()) {
		auto input = stdin.readln();
		auto i = new BufStream(input);
		auto r = parse_expr(i);
		writefln("%s, %s", r.consumed, i.head.length);
		assert(i.eof());
		writeln(r.result);
	}
}
