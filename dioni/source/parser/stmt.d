module parser.stmt;
import ast.expr, ast.stmt;
import sdpc;
import parser.utils, parser.expr, parser.atom;
import std.stdio;
@safe :
auto parse_assign(Stream i) {
	auto r = seq!(
		parse_lvalue,
		choice!(token_ws!"=", token_ws!"<-"),
		choice!(
			parse_expr,
			parse_qmark,
		),
		token_ws!";",
	)(i);
	r.r.name = "assign";
	if (!r.ok)
		return err_result!Stmt(r.r);
	bool delayed = r.result!1 == "<-";
	return ok_result!Stmt(new Assign(r.result!0, r.result!2, delayed), r.consumed, r.r);
}
auto parse_stmt_block(Stream i) {
	auto re = Reason(i, "statement block");
	auto r = seq!(
		token_ws!"{",
		many!(parse_stmt, true),
		token_ws!"}"
	)(i);
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
	r.r.name = "else block";
	if (!r.ok)
		return ok_result!(Stmt[])([], 0, r.r);
	return ok_result!(Stmt[])(r.result!1, r.consumed, r.r);
}
auto parse_if(Stream i) {
	auto r = seq!(
		token_ws!"if",
		token_ws!"(",
		parse_bool_expr,
		token_ws!")",
		parse_stmt_block,
		parse_else_block,
	)(i);
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
	r.r.name = "foreach";
	if (!r.ok)
		return err_result!Stmt(r.r);
	//writeln("Matched foreach");
	auto ret = new Foreach(cast(VarVal)r.result!2,
			       cast(VarVal)r.result!4, r.result!6);
	return ok_result!Stmt(ret, r.consumed, r.r);
}
auto parse_loop_var(Stream i) {
	auto r = seq!(
		parse_var,
		token_ws!"~"
	)(i);
	r.r.name = "loop variable";
	if (!r.ok)
		return ok_result!VarVal(null, 0, r.r);
	return ok_result!VarVal(cast(VarVal)r.result!0, r.consumed, r.r);
}
auto parse_loop(Stream i) {
	auto r = seq!(
		discard!(token_ws!"loop"),
		discard!(token_ws!"("),
		parse_loop_var,
		parse_range,
		discard!(token_ws!")"),
		parse_stmt_block
	)(i);
	r.r.name = "loop";
	if (!r.ok)
		return err_result!Stmt(r.r);
	//writeln("Matched loop");
	return ok_result!Stmt(
		new Loop(cast(VarVal)r.result!0,
			 r.result!1, r.result!2),
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
	r.r.name = "clear";
	if (!r.ok)
		return err_result!Stmt(r.r);
	return ok_result!Stmt(
		new Clear(r.result!0),
		r.consumed,
		r.r
	);
}
auto parse_aggregate_single(Stream i) {
	auto r = seq!(
		parse_lvalue,
		discard!(token_ws!"<<"),
		choice!(
			parse_expr,
			parse_new_expr
		),
		token_ws!";"
	)(i);
	r.r.name = "aggregate";
	if (!r.ok)
		return err_result!Stmt(r.r);
	return ok_result!Stmt(
		new Aggregate(r.result!0, [r.result!1]),
		r.consumed,
		r.r
	);
}
auto parse_aggregate(Stream i) {
	auto r = seq!(
		parse_lvalue,
		discard!(token_ws!"<<"),
		between!(token_ws!"{",chain!(
			choice!(
				parse_expr,
				parse_new_expr
			),
			arr_append!Expr,
			discard!(token_ws!",")
		), token_ws!"}"),
		token_ws!";"
	)(i);
	r.r.name = "aggregate many";
	if (!r.ok)
		return err_result!Stmt(r.r);
	return ok_result!Stmt(
		new Aggregate(r.result!0, r.result!1),
		r.consumed,
		r.r
	);
}

alias parse_new_stmt = cast_result!(Stmt, seq!(parse_new, discard!(token_ws!";")));

ParseResult!Stmt parse_stmt(Stream i) {
	return choice!(
		parse_if,
		parse_assign,
		parse_foreach,
		parse_loop,
		parse_clear,
		parse_aggregate,
		parse_aggregate_single,
		parse_new_stmt,
	)(i);
}
