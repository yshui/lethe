#include "render.h"

struct render_queue rndrq[N_RENDER_QUEUES];
size_t rndrq_msz[N_RENDER_QUEUES] = RENDER_QUEUE_MEMBER_SIZES;
