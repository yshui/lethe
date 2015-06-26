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
import ast.decl,
       ast.expr;
import parser.stmt,
       parser.utils,
       parser.atom,
       parser.expr;
import sdpc;
auto parse_event_parameter(Stream i) {
	auto re = Reason(i, "event parameter");
	if (i.starts_with("_")) {
		i.advance(1);
		return ok_result!EventParameter(new EventParameter(), 1, re);
	}

	auto r = choice!(
		seq!(
			token_ws!"~",
			parse_var_expr
		),
		seq!(
			token_ws!"=",
			parse_primary
		),
	)(i);
	r.r.name = "event parameter";
	if (!r.ok)
		return err_result!EventParameter(r.r);

	EventParameter ep;
	if (r.result!0 == "~")
		ep = new EventParameter(cast(Var)r.result!1);
	else
		ep = new EventParameter(r.result!1);
	return ok_result!EventParameter(ep, r.consumed, r.r);
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
auto parse_state_decl(Stream i) {
	auto r = seq!(
		token_ws!"state",
		identifier,
		parse_stmt_block,
		chain!(parse_state_transition_arr, arr_append, discard!(token_ws!",")),
		token_ws!";"
	)(i);
	auto re = r.r;
	re.name = "state";
	if (!r.ok)
		return err_result!Decl(re);

	return ok_result!Decl(new State(r.result!1, r.result!2, r.result!3), r.consumed, re);
}
