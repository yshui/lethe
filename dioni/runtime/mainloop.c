#include <export.h>
#include <actor.h>
#include <list.h>
#include <event.h>
#include <actor.h>
#include <particle.h>
#include <tag.h>
#include <string.h>
#include <stdio.h>
int run_particle_with_event(struct actor *a, struct event *e);

static inline void dump_event_queue(void) {
	struct event *ei;
	list_for_each(&event_queue, ei, q) {
		switch(ei->tgtt) {
		case GLOBAL:
			printf("Global\n");
			break;
		case FENCE:
			printf("Fence\n");
			break;
		case PARTICLE:
			printf("Particle\n");
			break;
		case PARTICLE_TYPE:
			printf("Particle type\n");
			break;
		case TAG:
			printf("Tag\n");
			break;
		}
	}
}

static inline void propagate_particle_data(void) {
	struct particle *pi, *nxt;
	list_for_each_safe(&changed_particles, pi, nxt, next_changed) {
		if (pi->deleted) {
			destroy_particle(pi);
			continue;
		}
		pi->changed = false;
		pi->current = !pi->current;
		pi->data[!pi->current] = pi->data[pi->current];
		list_del(&pi->next_changed);
	}
}

//Continue handling event until the queue is empty
//Return the number of events handled (not how many times events are handled)
int tick_start(void) {
	if (list_empty(&event_queue))
		return 0;
	event_fence();
	//dump_event_queue();

	int count = 0;
	while(!list_empty(&event_queue)) {
		struct event *ei = list_top(&event_queue, struct event, q);
		list_del(&ei->q);
		if (ei->tgtt == FENCE) {
			propagate_particle_data();
			//If there're event been generated, put a fence
			struct event *laste =
			       list_tail(&event_queue, struct event, q);
			if (laste && laste->tgtt != FENCE)
				event_fence();
		} else if (ei->tgtt == PARTICLE) {
			struct particle *p = (void *)ei->target;
			struct actor *ai;
			list_for_each(&p->actors, ai, silblings) {
				if (ai->astate == ACTOR_RUNNING)
					run_particle_with_event(ai, ei);
			}
		} else {
			struct actor *ai;
			list_for_each(&active_actors, ai, q) {
				if (ai->astate != ACTOR_RUNNING)
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
					break;
				default:
					assert(false);
				}
				if (matched) {
					int nstate = run_particle_with_event(ai, ei);
					if (nstate != NOT_HANDLED)
						ai->state = nstate;
					if (nstate == 0) {
						//Nil, stop actor
						list_del(&ai->q);
						list_del(&ai->silblings);
						free_actor(ai);
					} else if (nstate == 1) {
						//Deleted, remove particle
						ai->owner->deleted = true;
						mark_particle_as_changed(ai->owner);
					}
				}
			}
		}
		count++;
	}
	return count;
}
