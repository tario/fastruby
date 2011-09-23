require 'mkmf'
dir_config('fastruby_base')
CONFIG['CC'] = 'gcc'
create_makefile('fastruby_base')



