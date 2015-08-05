module parser.decl.decl;
import ast.decl,
       ast.type,
       ast.stmt;
import sdpc;
import parser.utils, parser.stmt, parser.decl;
@safe :
auto parse_type(Stream i) {
	auto r = choice!(
		token_ws!"int",
		token_ws!"float",
		token_ws!"vec2",
		token_ws!"vec3",
		token_ws!"vec4"
	)(i);
	r.r.name = "type";
	if (!r.ok)
		return err_result!TypeBase(r.r);

	TypeBase ret = null;
	final switch(r.result) {
	case "int":
		ret = new Type!int;
		break;
	case "float":
		ret = new Type!float;
		break;
	case "vec2":
		ret = new Type!(float, 2);
		break;
	case "vec3":
		ret = new Type!(float, 3);
		break;
	case "vec4":
		ret = new Type!(float, 4);
		break;
	}
	return ok_result(ret, r.consumed, r.r);
}

auto parse_arr_type(Stream i) {
	auto r = seq!(
		parse_type,
		token_ws!"+"
	)(i);
	r.r.name = "array type";
	if (!r.ok)
		return err_result!TypeBase(r.r);

	TypeBase ret = r.result!0.arr_of;
	return ok_result(ret, r.consumed, r.r);
}
auto parse_var_decl(Stream i) {
	auto r = seq!(
		choice!(
			parse_arr_type,
			parse_type
		),
		identifier
	)(i);
	r.r.name = "variable declaration";
	if (!r.ok)
		return err_result!Decl(r.r);
	StorageClass sc = StorageClass.Particle;
	auto ret = new Var(r.result!0, null, r.result!1, Protection.ReadWrite, sc);
	return ok_result!Decl(ret, r.consumed, r.r);
}

auto parse_untyped_var_decl(Stream i) {
	auto r = identifier(i);
	r.r.name = "Untyped var decl";
	if (!r.ok)
		return err_result!Decl(r.r);
	auto ret = new Var(new AnyType, null, r.result);
	return ok_result!Decl(ret, r.consumed, r.r);
}

auto parse_ctor(Stream i) {
	auto r = seq!(
		discard!(token_ws!">"),
		between!(token_ws!"(",
			chain!(choice!(
				parse_var_decl,
				parse_untyped_var_decl
			), arr_append!Decl, discard!(token_ws!","), true),
		token_ws!")"),
		parse_stmt_block
	)(i);
	r.r.name = "ctor";
	if (!r.ok)
		return err_result!Decl(r.r);
	auto c = new Ctor(r.result!0, r.result!1);
	return ok_result!Decl(c, r.consumed, r.r);
}

auto parse_decl(Stream i) {
	auto r = choice!(
		seq!(parse_var_decl, discard!(token_ws!";")),
		parse_state_decl,
		parse_ctor
	)(i);
	r.r.name = "declaration";
	if (!r.ok)
		return err_result!Decl(r.r);
	return ok_result(r.result, r.consumed, r.r);
}
auto parse_fn(Stream i) {
	auto r = seq!(
		identifier,
		between!(token_ws!"(",
			chain!(parse_var_decl, arr_append!Decl, discard!(token_ws!","), true),
		token_ws!")"),
		discard!(token_ws!"->"),
		parse_type,
		parse_stmt_block
	)(i);
	r.r.name = "function";
	if (!r.ok)
		return err_result!Decl(r.r);
	return ok_result!Decl(new Func(r.result!0, r.result!1, r.result!2, r.result!3),
	    r.consumed, r.r
	);
}
alias parse_particle_decl = cast_result!(Decl, parse_particle);
auto parse_top(Stream i) {
	Decl[] result = [];
	Reason re = Reason(i, "top level declaration");
	while(true) {
		auto r1 = parse_tag_decl(i);
		if (r1.ok) {
			result ~= r1.result;
			continue;
		}
		re = Reason(i, "top level declaration");
		re.dep ~= r1.r;
		auto r = choice!(
			parse_particle_decl,
			parse_event,
			parse_vertex,
			parse_fn
		)(i);
		re.dep ~= r.r.dep;
		if (!r.ok)
			break;
		result ~= r.result;
	}
	if (!i.eof) {
		import std.stdio : writeln;
		writeln(re.explain);
		return null;
	}
	return result;
}
