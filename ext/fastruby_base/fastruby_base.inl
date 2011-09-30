#include "ruby.h"
#include "node.h"
#include "env.h"

VALUE rb_cStackChunk;
VALUE rb_cFastRubyThreadData;
VALUE rb_cStackChunkReference;
VALUE rb_mFastRuby;

ID id_fastruby_thread_data;

#define PAGE_SIZE 0x1000
#define NUM_PAGES 0x1000
#define PAGE_MASK 0xFFF

struct STACKCHUNK {
	VALUE* pages[NUM_PAGES];
	int current_position;
	int frozen;
};

struct FASTRUBYTHREADDATA {
	VALUE exception;
};

struct STACKCHUNKREFERENCE {
	VALUE rb_stack_chunk;
};

static inline void stack_chunk_initialize(struct STACKCHUNK* sc) {
	// initialize pointers with zeros
	memset(sc->pages, 0, sizeof(sc->pages));

	sc->current_position = 0;
	sc->frozen = 0;
}

static inline int stack_chunk_frozen(struct STACKCHUNK* sc) {
	return sc->frozen;
}


static inline void stack_chunk_freeze(struct STACKCHUNK* sc) {
	sc->frozen = 1;
}

static inline int stack_chunk_get_current_position(struct STACKCHUNK* sc) {
	return sc->current_position;
}

 static inline void stack_chunk_set_current_position(struct STACKCHUNK* sc, int position) {
	if (sc->frozen == 0) {
		sc->current_position = position;
	}
 }


static inline void* stack_chunk_alloc(struct STACKCHUNK* sc, int size){

	if (sc->frozen) {
		rb_raise(rb_eSysStackError,"Trying to alloc frozen object");
	}

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
		int i;

		for (i=position_in_page; i<PAGE_SIZE; i++) {
		 sc->pages[page][i] = Qfalse;
		}

		for (i=0; i<size; i++) {
		 sc->pages[new_page][i] = Qfalse;
		}

		sc->current_position = new_page*PAGE_SIZE + size;

		address = sc->pages[new_page];

	} else {

		if (sc->pages[page ] == 0) {
			// alloc the page corresponding to current stack position
			sc->pages[page] = malloc(PAGE_SIZE*sizeof(VALUE));
		}

		int i;
		for (i=position_in_page; i<position_in_page+size; i++) {
		 sc->pages[page][i] = Qfalse;
		}

		sc->current_position += size;
		int new_page = sc->current_position / PAGE_SIZE;

		if (new_page >= NUM_PAGES) {
			rb_raise(rb_eSysStackError,"stack level too deep");
		}

		if (sc->pages[new_page ] == 0) {
			// alloc the page corresponding for the new stack position
			sc->pages[new_page] = malloc(PAGE_SIZE*sizeof(VALUE));
		}

		address = sc->pages[page]+position_in_page;
	}

	return address;
}

static inline void stack_chunk_mark(struct STACKCHUNK* sc) {
	// Mark local variables on each allocated page up to current_position
	int i;

	for (i=0; i<sc->current_position; i++) {
		int position_in_page = i & PAGE_MASK;
		int page = i / PAGE_SIZE;

		rb_gc_mark(sc->pages[page][position_in_page]);
	}
}

static inline void stack_chunk_free(struct STACKCHUNK* sc) {

	int i;
	for (i=0; i<NUM_PAGES;i++) {
		if (sc->pages[i] != 0) {
			free(sc->pages[i]);
		}
	}

	free(sc);
}

static inline VALUE rb_stack_chunk_create(VALUE self) {
	// alloc memory for struct
	struct STACKCHUNK* sc;

	// make ruby object to wrap the stack and let the ruby GC do his work
	VALUE ret = Data_Make_Struct(rb_cStackChunk,struct STACKCHUNK,stack_chunk_mark,stack_chunk_free,sc);

	stack_chunk_initialize(sc);

	return ret;
}

static inline struct STACKCHUNK* stack_chunk_get_struct(VALUE self) {
	struct STACKCHUNK* data;
	Data_Get_Struct(self,struct STACKCHUNK,data);

	return data;
}


static inline VALUE rb_stack_chunk_alloc(VALUE self, VALUE rb_size) {

	struct STACKCHUNK* data;
	Data_Get_Struct(self,struct STACKCHUNK,data);

	stack_chunk_alloc(data,FIX2INT(rb_size));
	return self;
}

static inline struct STACKCHUNKREFERENCE* stack_chunk_reference_initialize(struct STACKCHUNKREFERENCE *scr) {
	scr->rb_stack_chunk = Qnil;
	return scr;
}

static inline void stack_chunk_reference_assign(struct STACKCHUNKREFERENCE* scr, VALUE value) {
	scr->rb_stack_chunk = value;
}

static inline VALUE stack_chunk_reference_retrieve(struct STACKCHUNKREFERENCE* scr) {
	return scr->rb_stack_chunk;
}

static inline void stack_chunk_reference_mark(struct STACKCHUNKREFERENCE* scr) {
	rb_gc_mark(scr->rb_stack_chunk);
}

static inline void stack_chunk_reference_free(struct STACKCHUNKREFERENCE* scr) {
	free(scr);
}

static inline VALUE rb_stack_chunk_reference_assign(VALUE self, VALUE value) {
	struct STACKCHUNKREFERENCE* scr;
	Data_Get_Struct(self,struct STACKCHUNKREFERENCE,scr);

	scr->rb_stack_chunk = value;
	return scr->rb_stack_chunk;
}

static inline VALUE rb_stack_chunk_reference_retrieve(VALUE self) {
	struct STACKCHUNKREFERENCE* scr;
	Data_Get_Struct(self,struct STACKCHUNKREFERENCE,scr);

	return scr->rb_stack_chunk;
}

static inline VALUE rb_stack_chunk_reference_create() {
	// alloc memory for struct
	struct STACKCHUNKREFERENCE* scr;

	// make ruby object to wrap the stack and let the ruby GC do his work
	VALUE ret = Data_Make_Struct(rb_cStackChunkReference,struct STACKCHUNKREFERENCE,stack_chunk_reference_mark,stack_chunk_reference_free,scr);

	stack_chunk_reference_initialize(scr);

	return ret;
}

static inline void fastruby_thread_data_mark(struct FASTRUBYTHREADDATA* thread_data) {
	rb_gc_mark(thread_data->exception);
}

static inline VALUE rb_thread_data_create() {
	struct FASTRUBYTHREADDATA* thread_data;

	VALUE ret = Data_Make_Struct(rb_cFastRubyThreadData,struct FASTRUBYTHREADDATA,fastruby_thread_data_mark,0,thread_data);

	thread_data->exception = Qnil;

	return ret;
}

static inline struct FASTRUBYTHREADDATA* rb_current_thread_data() {
	VALUE rb_thread = rb_thread_current();
	VALUE rb_thread_data = rb_thread_local_aref(rb_thread,id_fastruby_thread_data);

	struct FASTRUBYTHREADDATA* thread_data = 0;

	if (rb_thread_data == Qnil) {
		rb_thread_data = rb_thread_data_create();
		rb_thread_local_aset(rb_thread,id_fastruby_thread_data,rb_thread_data);
	}

	Data_Get_Struct(rb_thread_data,struct FASTRUBYTHREADDATA,thread_data);
	return thread_data;
}

static void init_stack_chunk() {

	rb_mFastRuby = rb_define_module("FastRuby");
	rb_cStackChunk = rb_define_class_under(rb_mFastRuby, "StackChunk", rb_cObject);
	rb_cFastRubyThreadData = rb_define_class_under(rb_mFastRuby, "ThreadData", rb_cObject);

	id_fastruby_thread_data = rb_intern("fastruby_thread_data");

	rb_define_singleton_method(rb_cStackChunk, "create", rb_stack_chunk_create,0);
	rb_define_method(rb_cStackChunk, "alloc", rb_stack_chunk_alloc,1);

	rb_cStackChunkReference = rb_define_class_under(rb_mFastRuby, "StackChunkReference", rb_cObject);

	rb_define_singleton_method(rb_cStackChunkReference, "create", rb_stack_chunk_reference_create,0);
	rb_define_method(rb_cStackChunkReference, "stack_chunk=", rb_stack_chunk_reference_assign,1);
	rb_define_method(rb_cStackChunkReference, "stack_chunk", rb_stack_chunk_reference_retrieve, 0);
}

