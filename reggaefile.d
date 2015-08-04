import reggae;

void main(string[] args) {
	auto dioni = executable!(App("dioni/source/main.d", "$builddir/dioni"),
	    Flags("-g -debug"),
	    ImportPaths(["dioni/source", "dioni/sdpc/source"])
	);
	auto script_src = Target("$project/scripts/ball.dn");
	auto script = Target("$builddir/script.o",
	    "$builddir/dioni -r $project/dioni/runtime -g $builddir/gen-dioni -o $builddir/script.o $in",
	    [script_src, dioni]);
	auto ddioni = Target("$builddir/ddioni.d",
	    "$builddir/dioni --donly -D ddioni -o $builddir/ddioni.d $in",
	    [script_src, dioni]);

	auto lethe = executable!(App("source/main.d", "lethe"),
	    Flags("-g -debug"),
	    ImportPaths(["gfm", "derelict-gl3/source", "derelict-sdl2/source",
	                 "derelict-util/source", "colorize/source", "$builddir"])
	    );
	generateBuild(Build(lethe), args);
}
