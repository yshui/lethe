RUNTIME_SRC=runtime/actor.c \
	    runtime/event.c \
	    runtime/particle.c \
	    runtime/mainloop.c
RUNTIME_OBJ=$(RUNTIME_SRC:.c=.o)
MAIN_SRC=statefn.c
MAIN_OBJ=$(MAIN_SRC:.c=.o)
all: libscript.a
dioni:
	dub build
statefn.c particles.c export.h defs.h: dioni tests/011-run-test.dn
	./dioni tests/011-run-test.dn
libscript.a: $(RUNTIME_OBJ) $(MAIN_OBJ) export.h
	ar rcs libscript.a $(RUNTIME_OBJ) $(MAIN_OBJ)
	ranlib libscript.a
%.o: %.c
	gcc -g -c -o $@ $<
.PHONY: clean
clean:
	-rm $(MAIN_OBJ) $(RUNTIME_OBJ) dioni $(MAIN_SRC) libscript.a
