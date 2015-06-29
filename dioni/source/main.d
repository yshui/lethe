import std.stdio, std.file;
import parser;
import ast.symbols;
import sdpc;
void main(string[] argv) {
	if (argv.length < 2) {
		stderr.writefln("Usage: %s file", argv[0]);
		throw new Exception("Missing argument");
	}

	char[] file_content = cast(char[])read(argv[1]);
	auto i = new BufStream(cast(immutable(char)[])file_content);
	auto r = many!parse_particle(i);

	writefln("%s, %s", r.consumed, i.head.length);
	if (!i.eof)
		writeln(r.r.explain());
	else
		writeln(r.result);
	
	Symbols global = new Symbols(null);
	foreach(p; r.result)
		global.insert(p);
	foreach(p; r.result) {
		if (p.visited)
			continue;
		p.gen_symbols(global);
	}
	foreach(p; r.result)
		writeln(p.c_structs);
	foreach(p; r.result)
		writeln(p.c_code);
}
