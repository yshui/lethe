#pragma once
#include <stddef.h>
#include <stdint.h>
#include <export.h>

struct render_queue {
	int nvert;
	int vert_capacity;
	void *buf;
	int nindex;
	int index_capacity;
	uint32_t *indices;
};

extern struct render_queue rndrq[];
extern size_t rndrq_msz[];

static inline void render_queue_bind_buf(int index, void *buf, int cap) {
	rndrq[index].buf = buf;
	rndrq[index].vert_capacity = cap;
	rndrq[index].nvert = 0;
}

static inline void render_queue_bind_indices(int index, uint32_t *buf, int cap) {
	rndrq[index].indices = buf;
	rndrq[index].index_capacity = cap;
	rndrq[index].nindex = 0;
}
