#pragma once
#include <export.h>
#include <stdint.h>
#include <stdbool.h>
#include <assert.h>
#define TAGS_SIZE (MAX_TAG_ID/32+1)
struct tag {
	uint32_t tags[MAX_TAG_ID/32+1];
};

static inline void set_tag(struct tag *t, int tag_id) {
	t->tags[tag_id/32] |= 1<<(tag_id%32);
}

static inline bool has_tag(struct tag *t, int tag_id) {
	return (t->tags[tag_id/32]&(1<<(tag_id%32))) != 0;
}

static inline int next_tag(struct tag *t, int tag_id) {
	//Get the remainder of current tags entry
	assert(tag_id >= -1);
	uint32_t r = tag_id >= 0 ? t->tags[tag_id/32]>>(tag_id%32+1) : t->tags[0];
	if (r != 0)
		return tag_id+__builtin_ffs(r);
	int i = tag_id/32+1;
	while (i < TAGS_SIZE) {
		r = t->tags[i];
		if (r)
			return i*32+__builtin_ffs(r)-1;
		i++;
	}
	return -1;
}

