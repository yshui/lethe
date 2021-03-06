module ast.aggregator;
import ast.type, ast.expr, ast.symbols, ast.stmt, ast.decl;

abstract class Aggregator {
	@safe {
		string c_aggregate(const(Decl) v, const(Expr) e,
				const(Symbols) s) const {
			assert(false);
		}
		string c_assign(const(Decl) v, const(Expr) e,
				const(Symbols) s, bool delayed) const {
			assert(false);
		}
		string c_clear(const(Decl) v, const(Symbols) s) const {
			assert(false);
		}
		string c_foreach(const(Decl) v, const(Var) loop,
				const(Stmt)[] bdy, const(Symbols) s) const {
			assert(false);
		}
	}
}

class EventAggregator : Aggregator {

override :
	string c_aggregate(const(Decl) v, const(Expr) e, const(Symbols) s) const {
		auto vv = cast(const(NewExpr))e;
		assert(vv !is null, "Only events is allowed to be sent to global");
		TypeBase ety;
		auto ecode = vv.c_code(s, ety);
		assert(ety.type_match!(Type!Event), vv.name~" is not an event");
		//Create an event object
		auto res = "{\nstruct event *__new_event = alloc_event();\n";
		res ~= "__new_event->e."~vv.name~" = "~ecode~";\n";
		if (v.symbol == "global")
			res ~= "__new_event->tgtt = GLOBAL;\n";
		else {
			auto td = cast(const(Tag))v;
			auto vd = cast(const(Var))v;
			auto pd = cast(const(Particle))v;
			if (td !is null) {
				res ~= "__new_event->tgtt = TAG;\n";
				res ~= "__new_event->target = TAG_"~td.name~";\n";
			} else if (vd !is null) {
				res ~= "__new_event->tgtt = PARTICLE;\n";
				TypeBase ty;
				auto code = vd.c_access(AccessType.Read, ty);
				if (ty.type_match!ParticleHandle)
					res ~= "__new_event->target = "~code~";\n";
				else if (ty.type_match!(NamedType!Particle))
					//Real particle
					res ~= "__new_event->target = (size_t)"~code~"->__p;\n";
				else
					assert(false);
			} else if (pd !is null) {
				res ~= "__new_event->tgtt = PARTICLE_TYPE;\n";
				res ~= "__new_event->target = PARTICLE_"~pd.name~";\n";
			} else
				assert(false);
		}
		res ~= "queue_event(__new_event);\n}\n";
		return res;
	}
}

class RenderAggregator : Aggregator {

override :
	string c_aggregate(const(Decl) v, const(Expr) e, const(Symbols) s) const {
		//Renderer only accepts vertex
		import std.conv : to;
		auto rd = cast(const(RenderQ))v;
		assert(rd !is null);
		TypeBase ty;
		auto code = e.c_code(s, ty);
		auto rqv = "rndrq["~to!string(rd.id)~"]";
		if (ty.type_match!(Type!int)) {
			//Index are offseted by nvert
			code = "("~rqv~".nvert+"~code~")";
			auto res = "if("~rqv~".nindex < "~rqv~".index_capacity) {\n";
			res ~= "*("~rqv~".indices+"~rqv~".nindex) = "~code~";\n";
			res ~= rqv~".nindex++;\n}\n";
			return res;
		} else {
			auto vty = cast(NamedType!Vertex)ty;
			assert(vty !is null);
			assert(vty.name == rd.ty.name);
			auto res = "if("~rqv~".nvert < "~rqv~".vert_capacity) {\n";
			res ~= "*(((struct vertex_"~rd.ty.name~" *)"~rqv~".buf)+"~rqv~".nvert) = "~code~";\n";
			res ~= rqv~".nvert++;\n}\n";
			return res;
		}
	}
}

class HitboxAggregator : Aggregator {

override :
	string c_aggregate(const(Decl) v, const(Expr) e, const(Symbols) s) const {
		TypeBase ty;
		auto code = e.c_code(s, ty);
		auto vt = cast(const(NamedType!Vertex))ty;
		assert(vt !is null);
		auto vd = vt.instance;
		auto res = "{\nstruct hitbox *__p = alloc_hitbox();\n";
		//Make sure the vertex type has the right shape
		auto typename = "", tgt = "", type = "";
		if (vd.member.length == 3) {
			//3 members, a triangle
			foreach(m; vd.member)
				assert(m.ty.type_match!(Type!(float, 2)));
			typename = "triangle";
			tgt = "tr";
			type = "HITBOX_TRIANGLE";
		} else if (vd.member.length == 2) {
			//a circle
			assert(vd.member[0].ty.type_match!(Type!float));
			assert(vd.member[1].ty.type_match!(Type!(float, 2)));
			typename = "ball";
			tgt = "b";
			type = "HITBOX_BALL";
		} else
			assert(false);
		res ~= "struct vertex_"~vt.name~" __tmp = "~code~";\n";
		res ~= "__p->"~tgt~" = *(struct "~typename~" *)&__tmp;\n";
		res ~= "__p->type = "~type~";\n";
		res ~= "list_add(&__current->__p->hitboxes, &__p->q);\n";
		res ~= "}\n";
		return res;
	}
}
