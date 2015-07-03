module parser.decl.event;
import parser.decl, parser.utils;
import sdpc;
import ast.expr, ast.decl, ast.particle, ast.type;
auto parse_member_type(Stream i) {
	auto r = choice!(
		token_ws!"int",
		token_ws!"particle",
	)(i);
	r.r.name = "event member type";
	if (!r.ok)
		return err_result!TypeBase(r.r);
	TypeBase ret = null;
	final switch(r.result) {
	case "int":
		ret = new Type!int;
		break;
	case "particle":
		ret = new ParticleType;
		break;
	}
	return ok_result(ret, r.consumed, r.r);
}
auto parse_event_member(Stream i) {
	auto r = seq!(
		parse_member_type,
		identifier,
		token_ws!";"
	)(i);
	r.r.name = "event member";
	if (!r.ok)
		return err_result!VarDecl(r.r);
	return ok_result(new VarDecl(r.result!0, r.result!1), r.consumed, r.r);
}
auto parse_event(Stream i) {
	auto r = seq!(
		discard!(token_ws!"event"),
		identifier,
		discard!(token_ws!"{"),
		many!parse_event_member,
		token_ws!"}"
	)(i);
	r.r.name = "event definition";
	if (!r.ok)
		return err_result!Decl(r.r);
	return ok_result!Decl(new Event(r.result!0, r.result!1), r.consumed, r.r);
}

