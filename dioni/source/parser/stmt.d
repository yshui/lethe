module parser.stmt;
import ast.expr, ast.stmt;
import sdpc;
import parser.utils, parser.expr, parser.atom;
import std.stdio;
auto parse_assign(Stream i) {
	auto r = seq!(
		parse_lvalue,
		token_ws!"=",
		choice!(
			parse_expr,
			parse_qmark
		),
		token_ws!";",
	)(i);
	r.r.promote();
	r.r.name = "assign";
	if (!r.ok)
		return err_result!Stmt(r.r);
	return ok_result!Stmt(new Assign(r.result!0, r.result!2), r.consumed, r.r);
}
auto parse_stmt_block(Stream i) {
	auto re = Reason(i, "statement block");
	auto r = seq!(
		token_ws!"{",
		many!(parse_stmt, true),
		token_ws!"}"
	)(i);
	r.r.promote();
	r.r.name = "block";
	if (r.ok) {
		//writeln("Matched stmt block");
		return ok_result(r.result!1, r.consumed, r.r);
	}
	auto r2 = parse_stmt(i);
	r2.r.name = "single statement";
	if (r2.ok)
		return ok_result([r2.result], r2.consumed, r2.r);
	
	re.dep ~= [r.r, r2.r];
	return err_result!(Stmt[])(re);
}
auto parse_else_block(Stream i) {
	auto r = seq!(
		token_ws!"else",
		parse_stmt_block
	)(i);
	r.r.promote();
	r.r.name = "else block";
	if (!r.ok)
		return ok_result!(Stmt[])([], 0, r.r);
	return ok_result!(Stmt[])(r.result!1, r.consumed, r.r);
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
	r.r.promote();
	r.r.name = "if";
	if (!r.ok)
		return err_result!Stmt(r.r);
	//writeln("Matched if");
	auto ret = new If(r.result!2, r.result!4, r.result!5);
	return ok_result!Stmt(ret, r.consumed, r.r);
}
auto parse_foreach(Stream i) {
	auto r = seq!(
		token_ws!"foreach",
		token_ws!"(",
		parse_var,
		token_ws!"~",
		parse_lvalue,
		token_ws!")",
		parse_stmt_block
	)(i);
	r.r.promote();
	r.r.name = "foreach";
	if (!r.ok)
		return err_result!Stmt(r.r);
	//writeln("Matched foreach");
	auto ret = new Foreach(cast(Var)r.result!2,
			       cast(Var)r.result!4, r.result!6);
	return ok_result!Stmt(ret, r.consumed, r.r);
}
auto parse_loop_var(Stream i) {
	auto r = seq!(
		parse_var,
		token_ws!"~"
	)(i);
	r.r.promote();
	r.r.name = "loop variable";
	if (!r.ok)
		return ok_result!Var(null, 0, r.r);
	return ok_result!Var(cast(Var)r.result!0, r.consumed, r.r);
}
auto parse_loop(Stream i) {
	auto r = seq!(
		token_ws!"loop",
		token_ws!"(",
		parse_loop_var,
		parse_expr,
		token_ws!"..",
		parse_expr,
		token_ws!")",
		parse_stmt_block
	)(i);
	r.r.promote();
	r.r.name = "loop";
	if (!r.ok)
		return err_result!Stmt(r.r);
	//writeln("Matched loop");
	return ok_result!Stmt(
		new Loop(cast(Var)r.result!2,
			 r.result!3,
			 r.result!5, r.result!7),
		r.consumed,
		r.r
	);
}
auto parse_clear(Stream i) {
	auto r = seq!(
		parse_lvalue,
		token_ws!"~",
		token_ws!";"
	)(i);
	r.r.promote();
	r.r.name = "clear";
	if (!r.ok)
		return err_result!Stmt(r.r);
	return ok_result!Stmt(
		new Assign(r.result!0, null, Assign.Delayed),
		r.consumed,
		r.r
	);
}
auto parse_delayed_or_aggregate(Stream i) {
	auto r = seq!(
		parse_lvalue,
		choice!(token_ws!"<-", token_ws!"<<"),
		parse_expr,
		token_ws!";"
	)(i);
	r.r.promote();
	r.r.name = "delayed assign or aggregate";
	if (!r.ok)
		return err_result!Stmt(r.r);
	return ok_result!Stmt(
		new Assign(r.result!0, r.result!2,
			r.result!1 == "<-" ?
			    Assign.Delayed : Assign.Aggregate
		),
		r.consumed,
		r.r
	);
}
ParseResult!Stmt parse_stmt(Stream i) {
	return choice!(
		parse_if,
		parse_assign,
		parse_foreach,
		parse_loop,
		parse_clear,
		parse_delayed_or_aggregate
	)(i);
}
