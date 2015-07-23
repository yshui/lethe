import std.stdio, std.file;
import std.process : environment, execute;
import parser;
import ast.symbols, ast.decl, ast.aggregator, ast.type;
import sdpc;
@safe string c_particle_handler(const(Decl)[] s) {
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
	res ~= "\treturn next_state;\n}";
	return res;
}
@trusted compile(string gen_dir) {
	//Compile runtime
	if (exists("build-dioni") && isDir("build-dioni"))
		rmdirRecurse("build-dioni");
	mkdir("build-dioni");
	auto dioni_rt = environment["DIONI_RUNTIME_DIR"];
	string[] outputs;
	foreach(file; dirEntries(dioni_rt, SpanMode.shallow)) {
		import std.path : baseName;
		import std.string : endsWith;
		if (!file.name.endsWith(".c"))
			continue;
		auto o = "build-dioni/"~baseName(file)~".o";
		auto gcc = execute(["gcc", file, "-I"~gen_dir, "-I"~dioni_rt, "-c", "-g", "-o", o]);
		write(gcc.output);
		if (gcc.status != 0)
			throw new Exception("GCC failed to compile "~file);
		outputs ~= [o];
	}

	//Compile statefn.c
	auto gcc = execute(["gcc", gen_dir~"/statefn.c", "-I"~gen_dir, "-I"~dioni_rt, "-c", "-g", "-o", "build-dioni/statefn.c.o"]);
	write(gcc.output);
	if (gcc.status != 0)
		throw new Exception("GCC failed to compile statefn.c");
	outputs ~= ["build-dioni/statefn.c.o"];

	//Create archive
	auto ar = execute(["ar", "rcs", "libscript.a"]~outputs);
	writeln(ar.output);
	if (ar.status != 0)
		throw new Exception("Failed to create archive");

	auto ranlib = execute(["ranlib", "libscript.a"]);
	rmdirRecurse("build-dioni");
}
@safe void main(string[] argv) {
	if (argv.length < 2) {
		writefln("Usage: %s file", argv[0]);
		throw new Exception("Missing argument");
	}

	string gen_prefix = environment.get("DIONI_GEN_DIR");
	if (gen_prefix is null)
		gen_prefix = "gen-dioni";
	if (gen_prefix == "")
		gen_prefix = ".";

	if (!exists(gen_prefix))
		mkdir(gen_prefix);
	else if (!isDir(gen_prefix))
		throw new Exception(gen_prefix~" is not a directory");

	char[] file_content = cast(char[])read(argv[1]);
	auto i = new BufStream(file_content.idup);
	auto r = parse_top(i);
	auto mainf = File(gen_prefix~"/statefn.c", "w");
	auto defsf = File(gen_prefix~"/defs.h", "w");
	auto pf = File(gen_prefix~"/particle_creation.h", "w");
	auto exf = File(gen_prefix~"/export.h", "w");
	auto dinf = File(gen_prefix~"/interface.d", "w");
	Symbols global = new Symbols(null);
	auto gevent = new Var(new TypeBase, new EventAggregator, "global",
				  Protection.Const, StorageClass.Void);
	global.insert(gevent);


	if (r is null)
		return;
	writeln(r);
	
	foreach(p; r)
		global.insert(p);

	//auto renderer = new RenderQ("render", 0, new Type!Vertex("ballv", global));
	//global.insert(renderer);

	foreach(pd; r) {
		auto p = cast(Particle)pd;
		if (p is null)
			continue;
		if (p.visited)
			continue;
		p.resolve(global);
	}

	int pcnt = 0, ecnt = 0, tcnt = 0;
	dinf.writeln("module dioni.interface;\n");
	dinf.writeln("import dioni;\n");
	defsf.writeln("#pragma once\n");
	defsf.writeln("#include \"export.h\"");
	defsf.writeln("#include <vec.h>");
	defsf.writeln("#include <event.h>");
	defsf.writeln("#include <particle.h>");
	defsf.writeln("#include <tag.h>");
	defsf.writeln("#include <actor.h>");
	defsf.writeln("#include <list.h>");
	defsf.writeln("#include <range.h>");
	defsf.writeln("#include <render.h>");
	exf.writeln("#pragma once\n");
	exf.writeln("#include <vec.h>");
	exf.writeln("#define N_RENDER_QUEUES 1\n"); //XXX Place holder
	exf.writeln("struct event;\nstruct particle;\n");
	mainf.writeln("#include \"defs.h\"\n");
	mainf.writeln("#include \"particle_creation.h\"\n");
	pf.writeln("#include \"defs.h\"\n");

	auto punion = "union particle_variants {\n";
	auto eunion = "union event_variants {\n";
	foreach(pd; r) {
		auto p  = cast(Particle)pd,
		     e  = cast(Event)pd,
		     td = cast(Tag)pd,
		     vd = cast(Vertex)pd;
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
			dinf.writeln(e.d_structs);
			eunion ~= "struct event_"~e.symbol~" "~e.symbol~";\n";
			ecnt++;
		} else if (td !is null) {
			exf.writefln("#define TAG_%s %s\n", td.symbol, tcnt);
			tcnt++;
		} else if (vd !is null) {
			exf.writeln(vd.c_structs);
			exf.writeln("#define VERTEX_"~vd.name~"_SIZE sizeof(struct vertex_"~vd.name~")");
			dinf.writeln(vd.d_structs);
		}
	}
	mainf.writeln(c_particle_handler(r));
	exf.writeln(punion~"};\n");
	exf.writeln(eunion~"};\n");
	exf.writeln("#define MAX_TAG_ID "~to!string(tcnt)~"\n");
	exf.writeln("#define MAX_PARTICLE_ID "~to!string(pcnt)~"\n");
	exf.writeln("#define RENDER_QUEUE_MEMBER_SIZES { VERTEX_ballv_SIZE }");

	exf.close();
	mainf.close();
	defsf.close();
	dinf.close();

	compile(gen_prefix);
}
