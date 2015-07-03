import std.stdio, std.file;
import parser;
import ast.symbols, ast.particle;
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
	Symbols global = new Symbols(null);

	if (!i.eof) {
		writeln(r.r.explain());
		goto end;
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

	defsf.writeln("#include \"stdlib/vec.h\"\n");
	mainf.writeln("#include \"defs.h\"");
	foreach(id, pd; r.result) {
		auto p = cast(Particle)pd;
		if (p is null)
			continue;
		defsf.writefln("#define PARTICLE_%s %s\n", p.symbol, id);
		defsf.writeln(p.c_structs);
		mainf.writeln(p.c_code);
	}
end:
}
