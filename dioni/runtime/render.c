#include <render.h>

struct render_queue rndrq[N_RENDER_QUEUES];
size_t rndrq_msz[N_RENDER_QUEUES] = RENDER_QUEUE_MEMBER_SIZES;

void render_queue_bind_buf(int index, void *buf, size_t cap) {
	rndrq[index].buf = buf;
	rndrq[index].vert_capacity = cap;
	rndrq[index].nvert = 0;
}

void render_queue_bind_indices(int index, uint32_t *buf, size_t cap) {
	rndrq[index].indices = buf;
	rndrq[index].index_capacity = cap;
	rndrq[index].nindex = 0;
}

int render_queue_get_nind(int index) {
	return rndrq[index].nindex;
}
int render_queue_get_nvert(int index) {
	return rndrq[index].nvert;
}
