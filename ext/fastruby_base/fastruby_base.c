#include "fastruby_base.inl"

void Init_fastruby_base() {
	init_stack_chunk();
	init_class_extension();
	init_fastruby_method();
}
