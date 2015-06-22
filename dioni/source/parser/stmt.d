module stmt;
import ast.expr;
import sdpc;
auto parse_assign(Stream i) {
	auto r = seq!(
		parse_lvalue,
		token_ws!"=",
		parse_expr,
		token_ws!";",
	)(i);
	if (!r.ok)
		return err_result!Stmt();
	return ok_result!Stmt(new Assign(r.result!0, r.result!2), r.consumed);
}
auto parse_stmt_block(Stream i) {
	auto r = seq!(
		token_ws!"{".
		many!parse_stmt,
		token_ws!"}"
	)(i);
	if (r.ok)
		return ok_result(r.result!1, r.consumed);
	r = parse_stmt(i);
	if (r.ok)
		return ok_result([r.result], r.consumed);
	return err_result!(Stmt[])();
}
auto parse_else_block(Stream i) {
	auto r = seq!(
		token_ws!"else",
		parse_stmt_block
	)(i);
	if (!r.ok)
		return ok_result!(Stmt[])([], 0);
	return ok_result!(Stmt[])(r.result!1, r.consumed);
}
auto parse_if(Stream i) {
	auto r = seq!(
		token_ws!"if",
		token_ws!"(",
		parse_expr,
		token_ws!")",
		parse_stmt_block,
		parse_else_block,
	)(i);
	if (!r.ok)
		return err_result!Stmt();
	auto ret = new If(r.result!2, r.result!4, r.result!5);
	return ok_result!Stmt(ret, r.consumed);
}
auto parse_foreach(Stream i) {
	auto r = seq!(
		token_ws!"foreach",
		token_ws!"(",
		parse_var,
		token_ws!"~",
		parse_var,
		token_ws!")",
		parse_stmt_block
	)(i);
	if (!r.ok)
		return err_result!Stmt();
	auto ret = new Foreach(r.result!2, r.result!4, r.)
}
auto parse_loop_var(Stream i) {
	auto r = seq!(
		parse_var
		token_ws!"~",
	)(i);
	if (!r.ok)
		return ok_result!Var(null, 0);
	return ok_result(r.result!1, r.consumed);
}
auto parse_loop(Stream i) {
	auto r = seq!(
		token_ws!"loop",
		token_ws!"(",
		parse_loop_var,
		parse_expr,
		token_ws!"..",
		parse_expr,
		parse_stmt_block
	)(i);
	if (!r.ok)
		return err_result!Stmt();
	return ok_result(
		new Loop(r.result!2, r.result!3, r.result!5, r.result!6),
		r.consumed
	);
}
alias parse_stmt = choice!(
	parse_if,
	parse_assign,
	parse_foreach,
	parse_loop
);
