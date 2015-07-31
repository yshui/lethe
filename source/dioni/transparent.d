module dioni.transparent;

public import ddioni;
public import dioni.opaque;

struct dioniEvent {
	dioniEventTarget tgtt;
	size_t target;
	int event_type;
	dioniEventVariant v;
	void*[2] padding;
}

dioniEvent* alloc_event() {
	return cast(dioniEvent*)dioni.opaque.alloc_event();
}
void queue_event(dioniEvent* e) {
	dioni.opaque.queue_event(cast(dioniEventOpaque*)e);
}
