#include "ruby.h"
#include "setjmp.h"

#ifdef RUBY_1_8
#include "node.h"
#include "env.h"
#endif

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
	VALUE accumulator;
	VALUE rb_stack_chunk;
	void* last_plocals;
};

#ifdef RUBY_1_8
#define _RARRAY_LEN(x) (RARRAY(x)->len)
#define _RSTRING_PTR(x) (RSTRING(x)->ptr)
#endif

#ifdef RUBY_1_9


typedef enum {
    NOEX_PUBLIC    = 0x00,
    NOEX_NOSUPER   = 0x01,
    NOEX_PRIVATE   = 0x02,
    NOEX_PROTECTED = 0x04,
    NOEX_MASK      = 0x06,
    NOEX_BASIC     = 0x08,
    NOEX_UNDEF     = NOEX_NOSUPER,
    NOEX_MODFUNC   = 0x12,
    NOEX_SUPER     = 0x20,
    NOEX_VCALL     = 0x40,
    NOEX_RESPONDS  = 0x80
} rb_method_flag_t;

typedef enum {
    VM_METHOD_TYPE_ISEQ,
    VM_METHOD_TYPE_CFUNC,
    VM_METHOD_TYPE_ATTRSET,
    VM_METHOD_TYPE_IVAR,
    VM_METHOD_TYPE_BMETHOD,
    VM_METHOD_TYPE_ZSUPER,
    VM_METHOD_TYPE_UNDEF,
    VM_METHOD_TYPE_NOTIMPLEMENTED,
    VM_METHOD_TYPE_OPTIMIZED, /* Kernel#send, Proc#call, etc */
    VM_METHOD_TYPE_MISSING   /* wrapper for method_missing(id) */
} rb_method_type_t;

typedef struct rb_method_cfunc_struct {
    VALUE (*func)(ANYARGS);
    int argc;
} rb_method_cfunc_t;

typedef struct rb_method_attr_struct {
    ID id;
    VALUE location;
} rb_method_attr_t;

typedef struct rb_iseq_struct rb_iseq_t;

typedef struct rb_method_definition_struct {
    rb_method_type_t type; /* method type */
    ID original_id;
    union {
	rb_iseq_t *iseq;            /* should be mark */
	rb_method_cfunc_t cfunc;
	rb_method_attr_t attr;
	VALUE proc;                 /* should be mark */
	enum method_optimized_type {
	    OPTIMIZED_METHOD_TYPE_SEND,
	    OPTIMIZED_METHOD_TYPE_CALL
	} optimize_type;
    } body;
    int alias_count;
} rb_method_definition_t;

typedef struct rb_method_entry_struct {
    rb_method_flag_t flag;
    char mark;
    rb_method_definition_t *def;
    ID called_id;
    VALUE klass;                    /* should be mark */
} rb_method_entry_t;

rb_method_entry_t* rb_method_entry(VALUE klass, ID id);
void* rb_global_entry(ID id);

typedef struct RNode {
    unsigned long flags;
    char *nd_file;
    union {
	struct RNode *node;
	ID id;
	VALUE value;
	VALUE (*cfunc)(ANYARGS);
	ID *tbl;
    } u1;
    union {
	struct RNode *node;
	ID id;
	long argc;
	VALUE value;
    } u2;
    union {
	struct RNode *node;
	ID id;
	long state;
	struct rb_global_entry *entry;
	long cnt;
	VALUE value;
    } u3;
} NODE;


#define _RARRAY_LEN(x) RARRAY_LEN(x)
#define _RSTRING_PTR(x) RSTRING_PTR(x)
#endif

struct METHOD {
    VALUE klass, rklass;
    VALUE recv;
    ID id, oid;
    int safe_level;
    NODE *body;
};

        
RUBY_EXTERN void* ruby_current_thread;
# define NUM2PTR(x)   ((void*)(NUM2ULONG(x)))

static inline VALUE eval_code_block(void* plocals, void* pframe) {
  VALUE ___block_args[4];

  VALUE (*___func) (int, VALUE*, VALUE, VALUE);
  ___func = (void*)( NUM2PTR(rb_gvar_get(rb_global_entry(rb_intern("$last_eval_block")))));
  return ___func(0,___block_args,(VALUE)plocals,(VALUE)pframe);
}

VALUE fastruby_binding_eval(VALUE self, VALUE code) {

  void *plocals = NUM2PTR(rb_ivar_get(self, rb_intern("plocals")));
  void *pframe = NUM2PTR(rb_ivar_get(self, rb_intern("pframe")));
  VALUE locals = rb_ivar_get(self, rb_intern("locals"));
  VALUE locals_struct = rb_ivar_get(self, rb_intern("locals_struct"));

  VALUE rb_eFastRuby = rb_const_get(rb_cObject, rb_intern("FastRuby"));
  VALUE rb_cFastRubyMethod = rb_const_get(rb_eFastRuby, rb_intern("Method"));

  rb_funcall(rb_cFastRubyMethod, rb_intern("build_block"), 3, code, locals_struct, locals);

  return eval_code_block(plocals,pframe);

}

static inline VALUE create_fastruby_binding(void* pframe, void* plocals, VALUE locals_struct, VALUE locals) {
  
  VALUE rb_eFastRuby = rb_const_get(rb_cObject, rb_intern("FastRuby"));
  VALUE rb_cFastRubyBinding = rb_const_get(rb_eFastRuby, rb_intern("Binding"));
  VALUE new_binding = rb_funcall(rb_cFastRubyBinding, rb_intern("new"), 0);
  
  rb_ivar_set(new_binding, rb_intern("plocals"), PTR2NUM(plocals));
  rb_ivar_set(new_binding, rb_intern("pframe"), PTR2NUM(pframe));
  rb_ivar_set(new_binding, rb_intern("locals_struct"), locals_struct);
  rb_ivar_set(new_binding, rb_intern("locals"), locals);

  return new_binding;
}

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

typedef struct {
  int size;
  void *p1,*p2,*p3,*p4,*p5;
  VALUE data[0x10000];
} generic_scope_t;

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

  ((generic_scope_t*)address)->size = size;
	return address;
}

static inline void stack_chunk_mark(struct STACKCHUNK* sc) {
	// Mark local variables on each allocated page up to current_position
	int i;

	for (i=0; i<sc->current_position; ) {
		int position_in_page = i & PAGE_MASK;
		int page = i / PAGE_SIZE;

    generic_scope_t* scope = (void*)&(sc->pages[page][position_in_page]);

    if (scope->size == 0) {
      i = i + 1;
    } else {
  	  i = i + scope->size;
      int j;
      for (j=0;j<scope->size-6;j++) rb_gc_mark(scope->data[j]);
    }
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


static inline void fastruby_thread_data_mark(struct FASTRUBYTHREADDATA* thread_data) {
	rb_gc_mark(thread_data->exception);
	rb_gc_mark(thread_data->accumulator);
	rb_gc_mark(thread_data->rb_stack_chunk);
}

static inline VALUE rb_thread_data_create() {
	struct FASTRUBYTHREADDATA* thread_data;

	VALUE ret = Data_Make_Struct(rb_cFastRubyThreadData,struct FASTRUBYTHREADDATA,fastruby_thread_data_mark,0,thread_data);

	thread_data->exception = Qnil;
	thread_data->accumulator = Qnil;
	thread_data->rb_stack_chunk = Qnil;
	thread_data->last_plocals = 0;

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
}

static VALUE clear_method_hash_addresses(VALUE klass,VALUE rb_method_hash) {
  if (rb_method_hash != Qnil) {
	  VALUE rb_values = rb_funcall(rb_method_hash, rb_intern("values"),0);
	  void** address;
	  int i;

	  for (i = 0; i < _RARRAY_LEN(rb_values); i++) {
	  	address = (void**)NUM2PTR(rb_ary_entry(rb_values,i));
      *address = 0;
	  }
  }
  
  return Qnil;
}

static VALUE has_fastruby_function(VALUE self, VALUE rb_method_hash, VALUE mname) {
	ID id = rb_intern(_RSTRING_PTR(mname));
	VALUE tmp = rb_hash_aref(rb_method_hash, LONG2FIX(id));
	
	if (tmp != Qnil) {
		void** address = (void**)FIX2LONG(tmp);
		
		if (*address == 0) {
			return Qfalse;
		} else {
			return Qtrue;
		}
	}
	
	return Qfalse;
}

static void init_class_extension() {
	VALUE rb_mFastRubyBuilderModule = rb_define_module_under(rb_mFastRuby, "BuilderModule");
	rb_define_method(rb_mFastRubyBuilderModule, "clear_method_hash_addresses",clear_method_hash_addresses,1);
	rb_define_method(rb_mFastRubyBuilderModule, "has_fastruby_function",has_fastruby_function,2);
}

static VALUE fastruby_method_tree(VALUE self) {
	VALUE rb_tree_pointer = rb_ivar_get(self, rb_intern("@tree"));
	if (rb_tree_pointer == Qnil) return Qnil;
	VALUE* tree_pointer = (VALUE*)FIX2LONG(rb_tree_pointer);
	return *tree_pointer;
}

static VALUE fastruby_method_tree_pointer(VALUE self) {
	VALUE rb_tree_pointer = rb_ivar_get(self, rb_intern("@tree"));

	if (rb_tree_pointer == Qnil) {
		VALUE* tree_pointer = malloc(sizeof(VALUE*));
		rb_gc_register_address(tree_pointer);
		*tree_pointer = Qnil;
		rb_tree_pointer = LONG2FIX(tree_pointer);
		rb_ivar_set(self, rb_intern("@tree"), rb_tree_pointer);
	}

	return rb_tree_pointer;
}

static VALUE fastruby_method_tree_eq(VALUE self, VALUE val) {
	VALUE* tree_pointer = (VALUE*)FIX2LONG(fastruby_method_tree_pointer(self));
	*tree_pointer = val;
	return Qnil;
}

static void init_fastruby_method() {
	VALUE rb_cFastRubyMethod = rb_define_class_under(rb_mFastRuby, "Method", rb_cObject);
	rb_define_method(rb_cFastRubyMethod, "tree_pointer", fastruby_method_tree_pointer,0);
	rb_define_method(rb_cFastRubyMethod, "tree", fastruby_method_tree,0);
	rb_define_method(rb_cFastRubyMethod, "tree=", fastruby_method_tree_eq,1);

	VALUE rb_cFastRubyBinding = rb_define_class_under(rb_mFastRuby, "Binding", rb_cObject);
  rb_define_method(rb_cFastRubyBinding, "eval", fastruby_binding_eval, 1);
}

