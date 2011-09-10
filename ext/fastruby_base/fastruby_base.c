#include "ruby.h"
#include "node.h"
#include "env.h"

VALUE rb_cStackChunk;
VALUE rb_mFastRuby;

#define PAGE_SIZE 0x1000
#define NUM_PAGES 0x1000
#define PAGE_MASK 0xFFF

struct STACKCHUNK {
	void** pages[NUM_PAGES];
	int current_position;
};

struct STACKCHUNK* stack_chunk_create() {
	struct STACKCHUNK *sc = malloc(sizeof(struct STACKCHUNK));
	
	// initialize pointers with zeros
	memset(sc->pages, 0, sizeof(sc->pages));
	
	sc->current_position = 0;
	
	return sc;
}

void* stack_chunk_alloc(struct STACKCHUNK* sc, int size){
	void *address = 0;
	int position_in_page = sc->current_position & PAGE_MASK;
	int page = sc->current_position / PAGE_SIZE;
	
	if (position_in_page+size >= PAGE_SIZE) {
		int new_page = page+1;
	
		if (sc->pages[new_page ] == 0) {
			// alloc the page corresponding for the new stack position
			sc->pages[new_page] = malloc(PAGE_SIZE*sizeof(void*));
		}
		// alloc new page
		sc->current_position = new_page*PAGE_SIZE + size;
		
		address = &sc->pages[new_page][0];
		
	} else {
		sc->current_position += size;
		int new_page = sc->current_position / PAGE_SIZE;
		if (sc->pages[new_page ] == 0) {
			// alloc the page corresponding for the new stack position
			sc->pages[new_page] = malloc(PAGE_SIZE*sizeof(void*));
		}
		
		address = &sc->pages[page][position_in_page];
	}
	
	return address;
	
}

static void stack_chunk_mark(struct STACKCHUNK* sc) {
	// Do nothing, local variables will be marked by GC following reigistered address
}

static void stack_chunk_free(struct STACKCHUNK* sc) {
	
	int i;
	for (i=0; i<NUM_PAGES;i++) {
		if (sc->pages[i] != 0) {
			free(sc->pages[i]);
		}
	}
	
	// TODO: Unregister all locals addresses
	
	free(sc);
}

VALUE rb_stack_chunk_create(VALUE self) {
	// alloc memory for struct
	struct STACKCHUNK* sc = stack_chunk_create();
	
	// make ruby object to wrap the stack and let the ruby GC do his work
	return Data_Make_Struct(rb_cStackChunk,struct STACKCHUNK,stack_chunk_mark,stack_chunk_free,sc);
}

void Init_fastruby_base() {
	
	rb_mFastRuby = rb_define_module("FastRuby");
	rb_cStackChunk = rb_define_class_under(rb_mFastRuby, "StackChunk", rb_cObject);
	
	rb_define_singleton_method(rb_cStackChunk, "create", rb_stack_chunk_create,0);
}
