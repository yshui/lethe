#include "particle_creation.h"
#include "runtime/mainloop.h"

int main() {
	new_particle_Bootstrap();
	while(tick_start());
}
