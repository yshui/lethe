#pragma once
#define objpool_def(type, pool_size, name, field) \
static type *name##_pool = NULL; \
static int name##_water_mark = 0; \
static struct list_head name##_free = LIST_HEAD_INIT(name##_free); \
type *alloc_##name(void) { \
	if (!list_empty(&name##_free)) { \
		type *e = list_top(&name##_free, type, field); \
		list_del(&e->field); \
		return e; \
	} \
	if (name##_water_mark >= pool_size || name##_pool == NULL) { \
		name##_pool = malloc(sizeof(type)*pool_size); \
		name##_water_mark = 0; \
	} \
	return &name##_pool[name##_water_mark++]; \
} \
void free_##name(type *e) { \
	assert(e->field.next == e->field.prev && e->field.next == NULL); \
	list_add(&name##_free, &e->field); \
}

#define objpool_proto(type, name) \
type *alloc_##name(void); \
void free_##name(type *e);
