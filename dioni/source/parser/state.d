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
module parser.state;
import ast.state,
       ast.expr;
import parser.stmt,
       parser.utils,
       parser.atom;
import sdpc;
auto parse_event_parameter(Stream i) {
	auto re = Reason(i, "event parameter");
	if (i.starts_with("_")) {
		i.advance(1);
		return ok_result!EventParameter(
			new EventParameter(null, EventParameter.Ignore),
			1,
			re
		);
	}

	auto r = seq!(
		choice!(token_ws!"~", token_ws!"="),
		parse_var
	)(i);
	re = r.r;
	re.name = "event parameter";
	if (!r.ok)
		return err_result!EventParameter(re);

	int type = r.result!0 == "~" ? EventParameter.Assign : EventParameter.Match;
	return ok_result!EventParameter(
		new EventParameter(cast(Var)r.result!1, type),
		r.consumed,
		re
	);
}
auto parse_event(Stream i) {
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
		return err_result!Event(re);

	auto e = new Event(r.result!0, r.result!1);
	return ok_result(e, r.consumed, re);
}
auto parse_state_transition_arr(Stream i) {
	auto r = seq!(
		token_ws!"@",
		parse_event,
		parse_stmt_block,
		token_ws!"=>",
		identifier
	)(i);
	auto re = r.r;
	re.name = "transition table";
	if (!r.ok)
		return err_result!(StateTransition[])(re);
	auto st = new StateTransition(r.result!1, r.result!2, r.result!4);
	return ok_result([st], r.consumed, re);
}
auto parse_state_definition(Stream i) {
	auto r = seq!(
		token_ws!"state",
		identifier,
		chain!(parse_state_transition_arr, arr_append, discard!(token_ws!",")),
		token_ws!"."
	)(i);
	auto re = r.r;
	re.name = "state";
	if (!r.ok)
		return err_result!State(re);

	return ok_result(new State(r.result!1, r.result!2), r.consumed, re);
}
