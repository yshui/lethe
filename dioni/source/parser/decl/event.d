module parser.decl.event;
import parser.decl;
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
		ret = new Type!(int, 1);
		break;
	case "particle":
		ret = new Type!(Particle, 1);
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
		token_ws!"event",
		identifier,
		token_ws!"{",
		many!parse_event_member,
		token_ws!"}"
	)(i);
	r.r.name = "event definition";
	if (!r.ok)
		return err_result!Decl(r.r);
	return ok_result!Decl(new Event(r.result!1, r.result!2), r.consumed, r.r);
}

