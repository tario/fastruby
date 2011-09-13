#include "ruby.h"
#include "node.h"
#include "env.h"

VALUE rb_cStackChunk;
VALUE rb_mFastRuby;

#define PAGE_SIZE 0x1000
#define NUM_PAGES 0x1000
#define PAGE_MASK 0xFFF

struct STACKCHUNK {
	VALUE* pages[NUM_PAGES];
	int current_position;
	int frozen;
};

struct STACKCHUNK* stack_chunk_create() {
	struct STACKCHUNK *sc = malloc(sizeof(struct STACKCHUNK));
	
	// initialize pointers with zeros
	memset(sc->pages, 0, sizeof(sc->pages));
	
	sc->current_position = 0;
	sc->frozen = 0;
	
	return sc;
}

int stack_chunk_frozen(struct STACKCHUNK* sc) {
	return sc->frozen;
}


void stack_chunk_freeze(struct STACKCHUNK* sc) {
	sc->frozen = 1;
}

int stack_chunk_get_current_position(struct STACKCHUNK* sc) {
	return sc->current_position;
}

 void stack_chunk_set_current_position(struct STACKCHUNK* sc, int position) {
	sc->current_position = position; 
 }


void* stack_chunk_alloc(struct STACKCHUNK* sc, int size){
	void *address = 0;
	int position_in_page = sc->current_position & PAGE_MASK;
	int page = sc->current_position / PAGE_SIZE;
	
	if (position_in_page+size >= PAGE_SIZE) {
		int new_page = page+1;
		
		if (new_page >= NUM_PAGES) {
			rb_raise(rb_eSysStackError,"stack level too deep");
		}
	
		if (sc->pages[new_page ] == 0) {
			// alloc the page corresponding for the new stack position
			sc->pages[new_page] = malloc(PAGE_SIZE*sizeof(VALUE));
		}
		// alloc new page
		sc->current_position = new_page*PAGE_SIZE + size;
		
		address = &sc->pages[new_page][0];
		
	} else {
		sc->current_position += size;
		int new_page = sc->current_position / PAGE_SIZE;
		
		if (new_page >= NUM_PAGES) {
			rb_raise(rb_eSysStackError,"stack level too deep");
		}
		
		if (sc->pages[new_page ] == 0) {
			// alloc the page corresponding for the new stack position
			sc->pages[new_page] = malloc(PAGE_SIZE*sizeof(VALUE));
		}
		
		address = &sc->pages[page][position_in_page];
	}
	
	return address;
	
}

static void stack_chunk_mark(struct STACKCHUNK* sc) {
	// Do nothing, local variables will be marked by GC following reigistered address
}

static void stack_chunk_page_unregister(VALUE* page) {
	int i;
	for (i=0; i<PAGE_SIZE;i++) {
		rb_gc_unregister_address(page+i);
	}
}

static void stack_chunk_free(struct STACKCHUNK* sc) {
	
	int i;
	for (i=0; i<NUM_PAGES;i++) {
		if (sc->pages[i] != 0) {
			stack_chunk_page_unregister(sc->pages[i]);
			free(sc->pages[i]);
		}
	}
	
	free(sc);
}

VALUE rb_stack_chunk_create(VALUE self) {
	// alloc memory for struct
	struct STACKCHUNK* sc = stack_chunk_create();
	
	// make ruby object to wrap the stack and let the ruby GC do his work
	return Data_Make_Struct(rb_cStackChunk,struct STACKCHUNK,stack_chunk_mark,stack_chunk_free,sc);
}

struct STACKCHUNK* stack_chunk_get_struct(VALUE self) {
	struct STACKCHUNK* data;
	Data_Get_Struct(self,struct STACKCHUNK,data);

	return data;
}


VALUE rb_stack_chunk_alloc(VALUE self, VALUE rb_size) {
	
	struct STACKCHUNK* data;
	Data_Get_Struct(self,struct STACKCHUNK,data);
	
	stack_chunk_alloc(data,FIX2INT(rb_size));
	return self;
}

void Init_fastruby_base() {
	
	rb_mFastRuby = rb_define_module("FastRuby");
	rb_cStackChunk = rb_define_class_under(rb_mFastRuby, "StackChunk", rb_cObject);
	
	rb_define_singleton_method(rb_cStackChunk, "create", rb_stack_chunk_create,0);
	
	rb_define_method(rb_cStackChunk, "alloc", rb_stack_chunk_alloc,1);
	
}
