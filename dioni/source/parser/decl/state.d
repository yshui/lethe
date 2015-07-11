/**
  Grammar:
---
  state Name @ event1(...) { } => NextState1,
             ...
             @ eventn(...) { } => NextStaten.
---

---
  EventName(=condition, ~input)
  KeyPressed(=KEY_ESC)
  KeyPressed(~key_code) //Not very useful
  CollideWith(=CollisionGroup, ~object)
---
*/
module parser.decl.state;
import ast.decl,
       ast.expr;
import parser.stmt,
       parser.utils,
       parser.atom,
       parser.expr,
       parser.match;
import sdpc;
auto parse_event_parameter(Stream i) {
	auto re = Reason(i, "event parameter");

	auto r = parse_particle_match(i);
	if (!r.ok)
		re.dep ~= r.r;
	else {
		auto ep = new EventParameter(r.result);
		return ok_result(ep, r.consumed, r.r);
	}

	auto r2 = parse_cmp(i);
	if (!r2.ok) {
		re.dep ~= r2.r;
		return err_result!EventParameter(re);
	}

	auto cmp = cast(Cmp)r2.result;
	auto v = cast(Var)cmp.lhs;
	if (v is null) {
		r2.r.state = "failed";
		r2.r.msg = "Left-hand size of event parameter matching must be a variable";
		re.dep ~= r2.r;
		return err_result!EventParameter(re);
	}

	auto ep = new EventParameter(cmp);
	return ok_result!EventParameter(ep, r.consumed, r.r);
}
auto parse_condition(Stream i) {
	auto r = seq!(
		identifier,
		optional!(seq!(
			discard!(token_ws!"("),
			many!(parse_event_parameter, true),
			discard!(token_ws!")")
		))
	)(i);
	auto re = r.r;
	re.name = "event";
	if (!r.ok)
		return err_result!Condition(re);

	auto e = new Condition(r.result!0, r.result!1);
	return ok_result(e, r.consumed, re);
}
auto parse_state_transition(Stream i) {
	auto r = seq!(
		token_ws!"@",
		parse_condition,
		parse_stmt_block
	)(i);
	auto re = r.r;
	re.name = "transition table";
	if (!r.ok)
		return err_result!StateTransition(re);
	auto st = new StateTransition(r.result!1, r.result!2);
	return ok_result(st, r.consumed, re);
}
auto parse_state_decl(Stream i) {
	auto r = seq!(
		token_ws!"state",
		identifier,
		optional!parse_stmt_block,
		chain!(parse_state_transition, arr_append, discard!(token_ws!",")),
		token_ws!";"
	)(i);
	r.r.name = "state";
	if (!r.ok)
		return err_result!Decl(r.r);

	return ok_result!Decl(new State(r.result!1, r.result!2, r.result!3), r.consumed, r.r);
}
