module parser.decl;
import ast.decl,
       ast.expr;
import sdpc;
import parser.utils;
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
		token_ws!"[",
		token_ws!"]"
	)(i);
	r.r.name = "array type";
	if (!r.ok)
		return err_result!TypeBase(r.r);

	TypeBase ret = type_matching!(
		TypePattern!(ArrayType!(Type!(int, 1)), Type!(int, 1)),
		TypePattern!(ArrayType!(Type!(float, 1)), Type!(float, 1)),
		TypePattern!(ArrayType!(Type!(float, 2)), Type!(float, 2)),
		TypePattern!(ArrayType!(Type!(float, 3)), Type!(float, 3)),
		TypePattern!(ArrayType!(Type!(float, 4)), Type!(float, 4)),
	)([r.result!0]);

	return ok_result(ret, r.consumed, r.r);
}
auto parse_var_decl(Stream i) {
	auto r = seq!(
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
	auto ret = new VarDecl(r.result!0, r.result!1);
	return ok_result!Decl(ret, r.consumed, r.r);
}

auto parse_decl(Stream i) {
	auto r = choice!(
		parse_var_decl,
		parse_state_decl
	)(i);
	r.r.name = "declaration";
	if (!r.ok)
		return err_result!Decl(r.r);
	return ok_result(r.result, r.consumed, r.r);
}
