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

void render_queue_bind_buf(int index, void *buf, size_t cap);
void render_queue_bind_indices(int index, uint32_t *buf, size_t cap);
int render_queue_get_nvert(int index);
int render_queue_get_nind(int index);
