.ifndef PYTHON_INCLUDE_PATH 
PYTHON_INCLUDE_PATH = "/usr/local/include/python2.6"
.endif

default: pytrie.so

test: pytrie.so
	time python test.py

pytrie.so: pytrie.c
	gcc -shared -pthread -fPIC -fwrapv -O3 -fgcse-sm -fgcse-las -fgcse-after-reload -funsafe-loop-optimizations -fsched-spec-load -fsched-spec-load-dangerous -funsigned-char -fsee -fipa-pta -fbranch-target-load-optimize -Wall -fno-strict-aliasing -I${PYTHON_INCLUDE_PATH} -o pytrie.so pytrie.c
	
pytrie.c: pytrie.pyx platform.pxi settings.pxi
	cython pytrie.pyx
	
clean:
	rm pytrie.c pytrie.so
