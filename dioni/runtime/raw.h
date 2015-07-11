#pragma once

struct raw_particle {
	int t;
	void *p;
	struct tag *__tags;
	int id;
};
