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
       parser.expr;
import sdpc;
auto parse_event_parameter(Stream i) {
	auto re = Reason(i, "event parameter");

	auto r = seq!(
		parse_var_expr,
		token_ws!"~",
		parse_primary
	)(i);
	r.r.name = "event parameter";
	if (!r.ok)
		return err_result!EventParameter(r.r);
	
	auto condv = cast(Var)r.result!2;
	auto expr = r.result!2;
	auto var = cast(Var)r.result!0;
	if (condv !is null && condv.name == "_")
		expr = null;
	if (var.name == "_")
		var = null;

	auto ep = new EventParameter(var, expr);
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
auto parse_state_transition_arr(Stream i) {
	auto r = seq!(
		token_ws!"@",
		parse_condition,
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
	r.r.name = "state";
	if (!r.ok)
		return err_result!Decl(r.r);

	return ok_result!Decl(new State(r.result!1, r.result!2, r.result!3), r.consumed, r.r);
}
