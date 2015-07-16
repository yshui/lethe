#pragma once
#include <stddef.h>
#include "../export.h"

struct render_queue {
	int nmemb;
	int capacity;
	void *buf;
};

extern struct render_queue rndrq[];
extern size_t rndrq_msz[];

static inline void render_queue_bind_data(int index, void *buf, int cap) {
	rndrq[index].buf = buf;
	rndrq[index].capacity = cap;
	rndrq[index].nmemb = 0;
}
