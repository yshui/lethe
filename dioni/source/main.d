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
	auto r = parse_top(i);
	auto mainf = File("statefn.c", "w");
	auto defsf = File("defs.h", "w");
	auto pf = File("particles.c", "w");
	Symbols global = new Symbols(null);

	if (r is null)
		return;
	writeln(r);
	
	foreach(p; r)
		global.insert(p);
	foreach(pd; r) {
		auto p = cast(Particle)pd;
		if (p is null)
			continue;
		if (p.visited)
			continue;
		p.resolve(global);
	}

	int pcnt = 0, ecnt = 0, tcnt = 0;
	defsf.writeln("#include \"stdlib/vec.h\"");
	defsf.writeln("#include \"stdlib/event.h\"");
	defsf.writeln("#include \"stdlib/particle.h\"\n");
	mainf.writeln("#include \"defs.h\"\n");
	pf.writeln("#include \"stdlib/interface.h\"\n");
	pf.writeln("#include \"defs.h\"\n");

	auto punion = "union particle_variants {\n";
	foreach(pd; r) {
		auto p = cast(Particle)pd;
		auto e = cast(Event)pd;
		auto td = cast(TagDecl)pd;
		if (p !is null) {
			defsf.writefln("#define PARTICLE_%s %s\n", p.symbol, pcnt);
			defsf.writeln(p.c_macros);
			defsf.writeln(p.c_structs);
			mainf.writeln(p.c_code);
			pf.writeln(p.c_create);
			punion ~= "struct "~p.symbol~" "~p.symbol~";\n";
			pcnt ++;
		} else if (e !is null) {
			defsf.writefln("#define EVENT_%s %s\n", e.symbol, ecnt);
			defsf.writeln(e.c_structs);
			ecnt++;
		} else if (td !is null) {
			defsf.writefln("#define TAG_%s %s\n", td.symbol, tcnt);
			tcnt++;
		}
	}
	defsf.writeln(punion~"};\n");
}
