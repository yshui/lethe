module ast.decl;
import ast.expr,
       ast.stmt;

interface Decl {
	@property nothrow pure string symbol();
	@property pure string str();
	final string toString() {
		return str;
	}
}

class EventParameter {
	Var var;
	static enum {
		Match,
		Assign,
		Ignore
	}
	int type;
	this(Var v, int t) {
		assert(v !is null || t == Ignore);
		type = t;
		var = v;
	}
}

package pure nothrow string str_event_parameters(EventParameter[] ep) {
	auto res = "";
	foreach(i, e; ep) {
		final switch(e.type) {
		case EventParameter.Match:
			res ~= "=" ~ e.var.str;
			break;
		case EventParameter.Assign:
			res ~= "~" ~ e.var.str;
			break;
		case EventParameter.Ignore:
			res ~= "_";
			break;
		}
		if (i+1 != ep.length)
			res ~= ", ";
	}
	return res;
}

class Event {
	string name;
	EventParameter[] ep;
	this(string xname, EventParameter[] xep) {
		ep = xep;
		name = xname;
	}
	pure nothrow string str() {
		return name ~ "(" ~ str_event_parameters(ep) ~ ")";
	}
}

class StateTransition {
	Event e;
	string next;
	Stmt[] s;
	this(Event xe, Stmt[] xs, string xnext) {
		e = xe;
		s = xs;
		next = xnext;
	}
	pure nothrow string str() {
		auto res = "On event " ~ e.str ~ " do:\n";
		res ~= str_stmt_block(s);
		res ~= "=> " ~ next ~ "\n";
		return res;
	}
}

class State : Decl {
	StateTransition[] st;
	string name;
	this(string xname, StateTransition[] xst) {
		name = xname;
		st = xst;
	}
	override string symbol() {
		return name;
	}
	@property override string str() {
		auto res = "state(" ~ name ~ "):\n";
		foreach(ste; st)
			res ~= ste.str;
		return res;
	}
}

class VarDecl : Decl {
	TypeBase ty;
	string name;
	this(TypeBase xty, string xname) {
		name = xname;
		ty = xty;
	}
	override string str() {
		return name ~ ":" ~ ty.str ~ "\n";
	}
	override string symbol() {
		return name;
	}
}
