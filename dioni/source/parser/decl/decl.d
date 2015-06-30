module parser.decl.decl;
import ast.decl,
       ast.expr,
       ast.stmt;
import sdpc;
import parser.utils, parser.stmt;
public import parser.state;
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
		ret = new Type!(int, 1);
		break;
	case "float":
		ret = new Type!(float, 1);
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
		optional!(token_ws!"shared"),
		choice!(
			parse_arr_type,
			parse_type
		),
		identifier,
		token_ws!";"
	)(i);
	r.r.name = "variable declaration";
	if (!r.ok)
		return err_result!Decl(r.r);
	StorageClass sc = StorageClass.Particle;
	if (r.result!0 !is null && r.result!0 == "shared")
		sc = StorageClass.Shared;
	auto ret = new VarDecl(r.result!1, r.result!2, sc);
	return ok_result!Decl(ret, r.consumed, r.r);
}

auto parse_ctor(Stream i) {
	auto r = parse_stmt_block(i);
	r.r.name = "ctor";
	if (!r.ok)
		return err_result!Decl(r.r);
	auto c = new Ctor(r.result);
	return ok_result!Decl(c, r.consumed, r.r);
}

auto parse_decl(Stream i) {
	auto r = choice!(
		parse_var_decl,
		parse_state_decl,
		parse_ctor
	)(i);
	r.r.name = "declaration";
	if (!r.ok)
		return err_result!Decl(r.r);
	import std.stdio : writeln;
	writeln(typeid(r.result));
	return ok_result(r.result, r.consumed, r.r);
}

auto parse_top_decl(Stream i) {
	auto r = choice!(
		parse_particle,
		parse_event
	)(i);
	r.r.name = "top level declaration";
	if (!r.ok)
		return err_result!Decl(r.r);
	return ok_result(r.result, r.consumed, r.r);
}
