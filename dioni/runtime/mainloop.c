#include "../export.h"
#include "actor.h"
#include "list.h"
#include "event.h"
#include "actor.h"
#include "particle.h"
#include "tag.h"
int run_particle_with_event(struct actor *a, struct event *e);
bool run_particle(struct actor *a) {
	struct event *ei;
	bool handled = false;
	list_for_each(&global_event_queue, ei, q)
		handled = handled || (run_particle_with_event(a, ei) != NOT_HANDLED);
	list_for_each(&particle_type_event_queue[a->owner->type], ei, q)
		handled = handled || (run_particle_with_event(a, ei) != NOT_HANDLED);
	int now_tag = next_tag(&a->owner->t, -1);
	while(now_tag >= 0) {
		list_for_each(&tag_event_queue[now_tag], ei, q)
			handled = handled || (run_particle_with_event(a, ei) != NOT_HANDLED);
		now_tag = next_tag(&a->owner->t, now_tag);
	}
	return handled;
}

//Continue sending clock rising edges until nothing happens anymore
//Return the number of rising edges sent
int tick_start(void) {
	struct actor *ai;
	bool delta = true;
	int count = 0;
	while(delta) {
		delta = false;
		list_for_each(&active_actor, ai, q) {
			delta = delta || run_particle(ai);
			//Propagate next to current
			ai->owner->current = !ai->owner->current;
		}
		count++;
	}
	return count;
}
