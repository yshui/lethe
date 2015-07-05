import std.stdio, std.file;
import parser;
import ast.symbols, ast.decl;
import sdpc;
void main(string[] argv) {
	if (argv.length < 2) {
		stderr.writefln("Usage: %s file", argv[0]);
		throw new Exception("Missing argument");
	}

	char[] file_content = cast(char[])read(argv[1]);
	auto i = new BufStream(cast(immutable(char)[])file_content);
	auto r = many!parse_top_decl(i);
	auto mainf = File("statefn.c", "w");
	auto defsf = File("defs.h", "w");
	int pcnt = 0, ecnt = 0;
	Symbols global = new Symbols(null);

	if (!i.eof) {
		writeln(r.r.explain());
		return;
	} else
		writeln(r.result);
	
	foreach(p; r.result)
		global.insert(p);
	foreach(pd; r.result) {
		auto p = cast(Particle)pd;
		if (p is null)
			continue;
		if (p.visited)
			continue;
		p.resolve(global);
	}

	defsf.writeln("#include \"stdlib/vec.h\"");
	defsf.writeln("#include \"stdlib/event.h\"");
	defsf.writeln("#include \"stdlib/particle.h\"\n");
	mainf.writeln("#include \"defs.h\"\n");
	foreach(pd; r.result) {
		auto p = cast(Particle)pd;
		auto e = cast(Event)pd;
		if (p !is null) {
			defsf.writefln("#define PARTICLE_%s %s\n", p.symbol, pcnt);
			defsf.writeln(p.c_macros);
			defsf.writeln(p.c_structs);
			mainf.writeln(p.c_code);
			pcnt ++;
		} else if (e !is null) {
			defsf.writefln("#define EVENT_%s %s\n", e.symbol, ecnt);
			defsf.writeln(e.c_structs);
			ecnt++;
		}
	}
}
