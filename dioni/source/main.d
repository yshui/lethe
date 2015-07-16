import std.stdio, std.file;
import parser;
import ast.symbols, ast.decl, ast.aggregator, ast.type;
import sdpc;
string c_particle_handler(const(Decl)[] s) {
	//XXX this implementation is incomplete, run_particle function must
	//fetch events by itself, not via argument
	auto res = "int run_particle_with_event(struct actor *a, struct event *e) {\n";
	res ~= "\tint next_state;\n";
	res ~= "\tstruct particle *p = a->owner;\n";
	res ~= "\tswitch(p->type) {\n";
	foreach(d; s) {
		auto p = cast(const(Particle))d;
		if (p is null)
			continue;
		res ~= "\tcase PARTICLE_"~p.symbol~":\n";
		//Get current and next
		res ~= "\t\tnext_state = run_particle_"~p.symbol~"(&p->data[p->current]."~
			p.symbol~", &p->data[!p->current]."~p.symbol~", e, a->state);\n";
		res ~= "\t\tbreak;\n";
	}
	res ~= "\tdefault:\n\t\tassert(false);\n\t}\n";
	res ~= "\tp->current = !p->current;\n";
	res ~= "\treturn next_state;\n}";
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
	auto pf = File("particle_creation.h", "w");
	auto exf = File("export.h", "w");
	Symbols global = new Symbols(null);
	auto gevent = new Var(new TypeBase, new EventAggregator, "global",
				  Protection.Const, StorageClass.Void);
	global.insert(gevent);

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
	defsf.writeln("#include \"export.h\"");
	defsf.writeln("#include \"runtime/vec.h\"");
	defsf.writeln("#include \"runtime/raw.h\"");
	defsf.writeln("#include \"runtime/event.h\"");
	defsf.writeln("#include \"runtime/particle.h\"");
	defsf.writeln("#include \"runtime/tag.h\"");
	defsf.writeln("#include \"runtime/actor.h\"");
	defsf.writeln("#include \"runtime/list.h\"");
	defsf.writeln("#include \"runtime/range.h\"");
	exf.writeln("#pragma once\n");
	exf.writeln("#include \"runtime/vec.h\"");
	exf.writeln("#include \"runtime/raw.h\"\n");
	exf.writeln("#define N_RENDER_QUEUES 1\n"); //XXX Place holder
	exf.writeln("struct event;\nstruct particle;\n");
	mainf.writeln("#include \"defs.h\"\n");
	mainf.writeln("#include \"particle_creation.h\"\n");
	pf.writeln("#include \"defs.h\"\n");

	auto punion = "union particle_variants {\n";
	auto eunion = "union event_variants {\n";
	foreach(pd; r) {
		auto p = cast(Particle)pd;
		auto e = cast(Event)pd;
		auto td = cast(Tag)pd;
		if (p !is null) {
			exf.writefln("#define PARTICLE_%s %s\n", p.symbol, pcnt);
			exf.writeln(p.c_macros);
			exf.writeln(p.c_structs);
			//defsf.writeln(p.c_code(true));
			//defsf.writeln(p.c_create(true));
			mainf.writeln(p.c_code);
			mainf.writeln(p.c_run);
			pf.writeln(p.c_create);
			punion ~= "struct "~p.symbol~" "~p.symbol~";\n";
			pcnt ++;
		} else if (e !is null) {
			exf.writefln("#define EVENT_%s %s\n", e.symbol, ecnt);
			exf.writeln(e.c_structs);
			eunion ~= "struct event_"~e.symbol~" "~e.symbol~";\n";
			ecnt++;
		} else if (td !is null) {
			exf.writefln("#define TAG_%s %s\n", td.symbol, tcnt);
			tcnt++;
		}
	}
	mainf.writeln(c_particle_handler(r));
	exf.writeln(punion~"};\n");
	exf.writeln(eunion~"};\n");
	exf.writeln("#define MAX_TAG_ID "~to!string(tcnt)~"\n");
	exf.writeln("#define MAX_PARTICLE_ID "~to!string(pcnt)~"\n");
	exf.writeln("#define RENDER_QUEUE_MEMBER_SIZEZ { VERTEX_Ball_SIZE }");
}
