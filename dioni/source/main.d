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
	auto r = many!parse_top_decl(i);

	writefln("%s, %s", r.consumed, i.head.length);
	if (!i.eof)
		writeln(r.r.explain());
	else
		writeln(r.result);
	
	Symbols global = new Symbols(null);
	foreach(p; r.result)
		global.insert(p);
	foreach(pd; r.result) {
		auto p = cast(Particle)pd;
		if (p is null)
			continue;
		if (p.visited)
			continue;
		p.gen_symbols(global);
	}

	auto mainf = File("statefn.c", "w");
	auto defsf = File("defs.h", "w");
	defsf.writeln("#include \"stdlib/vec.h\"\n");
	foreach(id, p; r.result)
		defsf.writefln("#define PARTICLE_%s %s\n", p.symbol, id);

	foreach(p; r.result)
		defsf.writeln(p.c_structs);

	mainf.writeln("#include \"defs.h\"");
	foreach(p; r.result)
		mainf.writeln(p.c_code);


}
