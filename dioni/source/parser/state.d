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
import ast.state,
       ast.expr;
import parser.stmt,
       parser.utils,
       parser.atom;
import sdpc;
auto parse_event_parameter(Stream i) {
	if (i.starts_with("_")) {
		i.advance(1);
		return ok_result!EventParameter(
			new EventParameter(null, EventParameter.Ignore),
			1
		);
	}

	auto r = seq!(
		choice!(token_ws!"~", token_ws!"="),
		parse_var
	)(i);
	if (!r.ok)
		return err_result!EventParameter();

	int type = r.result!0 == "~" ? EventParameter.Assign : EventParameter.Match;
	return ok_result!EventParameter(
		new EventParameter(cast(Var)r.result!1, type),
		r.consumed
	);
}
auto parse_event(Stream i) {
	auto r = seq!(
		identifier,
		token_ws!"(",
		many!parse_event_parameter,
		token_ws!")"
	)(i);
	if (!r.ok)
		return err_result!Event();

	auto e = new Event(r.result!0, r.result!2);
	return ok_result(e, r.consumed);
}
auto parse_state_transition_arr(Stream i) {
	auto r = seq!(
		token_ws!"@",
		parse_event,
		parse_stmt_block,
		token_ws!"=>",
		identifier
	)(i);
	if (!r.ok)
		return err_result!(StateTransition[])();
	auto st = new StateTransition(r.result!1, r.result!2, r.result!4);
	return ok_result([st], r.consumed);
}
auto parse_state_definition(Stream i) {
	auto r = seq!(
		token_ws!"state",
		identifier,
		chain!(parse_state_transition_arr, arr_append, discard!(token_ws!",")),
		token_ws!"."
	)(i);
	if (!r.ok)
		return err_result!State();

	return ok_result(new State(r.result!1, r.result!2), r.consumed);
}
