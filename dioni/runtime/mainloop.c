#include "../export.h"
#include "actor.h"
#include "list.h"
#include "event.h"
#include "actor.h"
#include "particle.h"
#include "tag.h"
int run_particle_with_event(struct actor *a, struct event *e);

//Continue handling event until the queue is empty
//Return the number of events handled (not how many times events are handled)
int tick_start(void) {
	struct actor *ai;
	bool delta = true;
	int count = 0;
	while(!list_empty(&event_queue)) {
		struct event *ei = list_top(&event_queue, struct event, q);
		list_del(&ei->q);
		if (ei->tgtt == PARTICLE) {
			struct particle *p = get_particle_by_id(ei->target);
			struct actor *ai;
			list_for_each(&p->actors, ai, silblings) {
				if (ai->astate == RUNNING)
					run_particle_with_event(ai, ei);
			}
		} else {
			struct actor *ai;
			list_for_each(&active_actors, ai, q) {
				if (ai->state != RUNNING)
					continue;
				bool matched = false;
				switch(ei->tgtt) {
				case PARTICLE_TYPE:
					//XXX maybe give each particle type its
					//own list
					matched = ei->target == ai->owner->type;
					break;
				case TAG:
					matched = has_tag(&ai->owner->t, ei->target);
					break;
				case GLOBAL:
					matched = true;
				default:
					assert(false);
				}
				if (matched)
					run_particle_with_event(ai, ei);
			}
		}
		count++;
	}
	return count;
}