import std.stdio, std.file;
import parser;
import ast.symbols, ast.decl;
import sdpc;
string c_particle_handler(const(Decl)[] s) {
	//XXX this implementation is incomplete, run_particle function must
	//fetch events by itself, not via argument
	auto res = "int run_particle(struct actor *a, struct raw_event *re) {\n";
	res ~= "\tstruct particle *p = a->owner;\n";
	res ~= "\tswitch(p->type) {\n";
	foreach(d; s) {
		auto p = cast(const(Particle))d;
		if (p is null)
			continue;
		res ~= "\tcase PARTICLE_"~p.symbol~":\n";
		//Get current and next
		res ~= "\t\tstruct "~p.symbol;
		res ~= " *current = &p->data[p->current]."~p.symbol;
		res ~= ", *next = &p->data[!p->current]."~p.symbol~";\n";
		res ~= "\t\treturn run_particle_"~p.symbol~"(current, next, re, a->state);\n";
	}
	res ~= "\t}\n}\n";
	return res;
}
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
	defsf.writeln("#pragma once\n");
	defsf.writeln("#include \"runtime/vec.h\"");
	defsf.writeln("#include \"runtime/raw.h\"");
	defsf.writeln("struct event;\nstruct particle;\n");
	mainf.writeln("#include \"defs.h\"\n");
	pf.writeln("#include \"runtime/interface.h\"\n");
	pf.writeln("#include \"defs.h\"\n");

	auto punion = "union particle_variants {\n";
	auto eunion = "union event_variants {\n";
	foreach(pd; r) {
		auto p = cast(Particle)pd;
		auto e = cast(Event)pd;
		auto td = cast(TagDecl)pd;
		if (p !is null) {
			defsf.writefln("#define PARTICLE_%s %s\n", p.symbol, pcnt);
			defsf.writeln(p.c_macros);
			defsf.writeln(p.c_structs);
			defsf.writeln(p.c_code(true));
			defsf.writeln(p.c_create(true));
			mainf.writeln(p.c_code);
			mainf.writeln(p.c_run);
			pf.writeln(p.c_create);
			punion ~= "struct "~p.symbol~" "~p.symbol~";\n";
			pcnt ++;
		} else if (e !is null) {
			defsf.writefln("#define EVENT_%s %s\n", e.symbol, ecnt);
			defsf.writeln(e.c_structs);
			eunion ~= "struct event_"~e.symbol~" "~e.symbol~";\n";
			ecnt++;
		} else if (td !is null) {
			defsf.writefln("#define TAG_%s %s\n", td.symbol, tcnt);
			tcnt++;
		}
	}
	mainf.writeln(c_particle_handler(r));
	defsf.writeln(punion~"};\n");
	defsf.writeln(eunion~"};\n");
	defsf.writeln("#define MAX_TAG_ID "~to!string(tcnt)~"\n");
	defsf.writeln("#define MAX_PARTICLE_ID "~to!string(pcnt)~"\n");
}
