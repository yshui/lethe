module ast.state;
import ast.expr,
       ast.stmt;
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

class Event {
	string name;
	EventParameter[] ep;
	this(string xname, EventParameter[] xep) {
		ep = xep;
		name = xname;
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
}

class State {
	StateTransition[] st;
	string name;
	this(string xname, StateTransition[] xst) {
		name = xname;
		st = xst;
	}
}
