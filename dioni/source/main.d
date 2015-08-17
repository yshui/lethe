import std.stdio, std.file;
import std.process : environment, execute;
import parser;
import ast.symbols, ast.decl, ast.aggregator, ast.type, ast.builtin;
import sdpc;
import std.getopt;
import error;
import std.exception : enforceEx;
private alias enforce = enforceEx!CompileError;
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
@trusted compile(string rdir, string gdir, string ofile, bool opt) {
	//Compile runtime
	if (exists("build-dioni") && isDir("build-dioni"))
		rmdirRecurse("build-dioni");
	mkdir("build-dioni");
	string[] outputs;
	string[] cflags = ["-Wall"];
	if (opt)
		cflags ~= ["-O2"];
	foreach(file; dirEntries(rdir, SpanMode.shallow)) {
		import std.path : baseName;
		import std.string : endsWith;
		if (!file.name.endsWith(".c"))
			continue;
		auto o = "build-dioni/"~baseName(file)~".o";
		auto gcc = execute(["gcc", file, "-I"~gdir, "-I"~rdir, "-c", "-g", "-o", o]~cflags);
		write(gcc.output);
		if (gcc.status != 0)
			throw new Exception("GCC failed to compile "~file);
		outputs ~= [o];
	}

	//Compile statefn.c
	auto gcc = execute(["gcc", gdir~"/statefn.c", "-I"~gdir, "-I"~rdir, "-c", "-g", "-o", "build-dioni/statefn.c.o"]~cflags);
	write(gcc.output);
	if (gcc.status != 0)
		throw new Exception("GCC failed to compile statefn.c");
	outputs ~= ["build-dioni/statefn.c.o"];

	//Compile particle_interface.c
	gcc = execute(["gcc", gdir~"/particle_interface.c", "-I"~gdir, "-I"~rdir, "-c", "-g", "-o", "build-dioni/particle_interface.c.o"]~cflags);
	write(gcc.output);
	if (gcc.status != 0)
		throw new Exception("GCC failed to compile particle_interface.c");
	outputs ~= ["build-dioni/particle_interface.c.o"];

	//Create archive
	auto ar = execute(["ld", "-r"]~outputs~["-o", ofile]);
	writeln(ar.output);
	if (ar.status != 0)
		throw new Exception("Failed to create archive");

	rmdirRecurse("build-dioni");
}

@safe void main(string[] argv) {
	string runtime_dir = "runtime",
	       result_dir = "gen-dioni",
	       input_file = "",
	       dmodule_name = "dioni",
	       output_file = "script.o";
	bool gen_dmodule = false, optimize = false;
	() @trusted {
		auto options = getopt(argv,
			"runtime|r", &runtime_dir,
			"result|g", &result_dir,
			"dmodule|D", &dmodule_name,
			"output|o", &output_file,
			"donly", &gen_dmodule,
			"release|O", &optimize
		);
		if (options.helpWanted)
			defaultGetoptPrinter("Usage:", options.options);
		assert(argv.length != 1);
		input_file = argv[1];
	}();

	if (!exists(result_dir))
		mkdir(result_dir);
	else if (!isDir(result_dir))
		throw new Exception(result_dir~" is not a directory");

	auto file_content = readText(input_file);
	auto i = new BufStream(file_content);
	auto r = parse_top(i);

	Symbols global = new Symbols(null);
	auto gevent = new Var(new TypeBase, new EventAggregator, "global",
				  Protection.Const, StorageClass.Void);
	global.insert(gevent);
	initBuiltin(global);

	writeln(r);

	foreach(p; r) {
		auto old = global.lookup(p.symbol);
		if (old !is null) {
			auto fn = cast(const(Func))old;
			auto o = cast(const(Overloaded))old;
			auto nfn = cast(const(Func))p;
			enforce(nfn !is null, "Duplicated symbol "~p.symbol);
			if (fn !is null) {
				auto no = new Overloaded(fn.symbol, [fn, nfn]);
				global.replace(no);
			} else if (o !is null) {
				auto no = new Overloaded(fn.symbol, o.fn~[nfn]);
				global.replace(no);
			} else
				enforce(false, "Duplicate symbol "~p.symbol);
		} else
			global.insert(p);
	}

	//Temporary workaround until we have render queue syntax
	//Let's get a demo done first
	auto renderer = new RenderQ("render", 0, new NamedType!Vertex("ballv", global));
	global.insert(renderer);

	foreach(pd; r) {
		auto p = cast(Particle)pd;
		if (p is null)
			continue;
		if (p.visited)
			continue;
		p.resolve(global);
	}
	int pcnt = 0, ecnt = 0, tcnt = 0;
	if (gen_dmodule) {
		string ofile = result_dir~"/d_interface.d";
		if (output_file != "")
			ofile = output_file;
		string old_content = "";
		if (exists(ofile) && isFile(ofile))
			old_content = readText(ofile);
		auto new_content = "";
		auto d_eunion = "union dioniEventVariant {\n";
		auto d_eev = "enum dioniEventType {\n";
		auto d_etag = "enum dioniTag {\n";
		auto d_ep = "enum dioniParticleType {\n";
		auto d_pfn = "extern(C) {\n";
		new_content ~= "module "~dmodule_name~";\n\n";
		new_content ~= "import dioni.opaque, gfm.math;\n\n";
		foreach(pd; r) {
			auto p  = cast(Particle)pd,
			     e  = cast(Event)pd,
			     td = cast(Tag)pd,
			     vd = cast(Vertex)pd;
			if (p !is null) {
				d_pfn ~= "\t"~p.d_create_proto;
				d_ep ~= p.symbol~" = "~to!string(pcnt)~",\n";
				pcnt++;
			} else if (e !is null) {
				d_eev ~= e.symbol~" = "~to!string(ecnt)~",\n";
				new_content ~= e.d_structs~"\n";
				d_eunion ~= "dioniEvent_"~e.symbol~" "~e.symbol~";\n";
				ecnt++;
			} else if (td !is null) {
				d_etag ~= td.symbol~" = "~to!string(tcnt)~",\n";
				tcnt++;
			} else if (vd !is null)
				new_content ~= vd.d_structs~"\n";
		}
		new_content ~= d_eunion~"}\n\n";
		if (ecnt > 0)
			new_content ~= d_eev~"}\n\n";
		if (tcnt > 0)
			new_content ~= d_etag~"}\n\n";
		if (pcnt > 0) {
			new_content ~= d_ep~"}\n\n";
			new_content ~= d_pfn~"}\n\n";
		}
		if (new_content != old_content) {
			auto dinf = File(ofile, "w");
			dinf.write(new_content);
		} else
			writeln("File content is the same, won't touch it.");
		return;
	}

	auto mainf = File(result_dir~"/statefn.c", "w");
	auto defsf = File(result_dir~"/defs.h", "w");
	auto pf = File(result_dir~"/particle_creation.h", "w");
	auto pinf = File(result_dir~"/particle_interface.c", "w");
	auto exf = File(result_dir~"/export.h", "w");
	auto fnf = File(result_dir~"/functions.h", "w");

	fnf.writeln("#pragma once\n");
	defsf.writeln("#pragma once\n");
	defsf.writeln("#include \"export.h\"");
	defsf.writeln("#include <vec.h>");
	defsf.writeln("#include <event.h>");
	defsf.writeln("#include <particle.h>");
	defsf.writeln("#include <tag.h>");
	defsf.writeln("#include <actor.h>");
	defsf.writeln("#include <list.h>");
	defsf.writeln("#include <range.h>");
	defsf.writeln("#include <rand.h>");
	defsf.writeln("#include <render.h>");
	defsf.writeln("#include <collision.h>");
	exf.writeln("#pragma once\n");
	exf.writeln("#include <stddef.h>");
	exf.writeln("#include <vec.h>");
	exf.writeln("#define N_RENDER_QUEUES 1\n"); //XXX Place holder
	exf.writeln("struct event;\nstruct particle;\n");
	mainf.writeln("#include \"defs.h\"\n");
	mainf.writeln("#include \"functions.h\"\n");
	mainf.writeln("#include \"particle_creation.h\"\n");
	pf.writeln("#include \"defs.h\"\n");
	pinf.writeln("#include \"defs.h\"\n");

	auto punion = "union particle_variants {\n";
	auto eunion = "union event_variants {\n";
	foreach(pd; r) {
		auto p  = cast(Particle)pd,
		     e  = cast(Event)pd,
		     td = cast(Tag)pd,
		     vd = cast(Vertex)pd,
		     fn = cast(Callable)pd;
		if (p !is null) {
			exf.writefln("#define PARTICLE_%s %s\n", p.symbol, pcnt);
			exf.writeln(p.c_macros);
			exf.writeln(p.c_structs);
			//defsf.writeln(p.c_code(true));
			//defsf.writeln(p.c_create(true));
			mainf.writeln(p.c_code);
			mainf.writeln(p.c_run);
			pf.writeln(p.c_create(true));
			pinf.writeln(p.c_create(false));
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
		} else if (vd !is null) {
			exf.writeln(vd.c_structs);
			exf.writeln("#define VERTEX_"~vd.name~"_SIZE sizeof(struct vertex_"~vd.name~")");
		} else if (fn !is null) {
			fnf.writeln(fn.c_code(global, false));
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
	pinf.close();
	pf.close();
	fnf.close();

	compile(runtime_dir, result_dir, output_file, optimize);
}
