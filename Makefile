.ifndef PYTHON_INCLUDE_PATH 
PYTHON_INCLUDE_PATH = "/usr/local/include/python2.6"
.endif

default: pytrie.so

test: pytrie.so
	time python test.py

pytrie.so: pytrie.c
	gcc -shared -pthread -fPIC -fwrapv -O3 -funsafe-loop-optimizations -fsched-spec-load -funsigned-char -fsee -fipa-pta -fbranch-target-load-optimize -Wall -fno-strict-aliasing -I${PYTHON_INCLUDE_PATH} -o pytrie.so pytrie.c	
	
pytrie.c: build/pytrie.pyx platform.pxi settings.pxi
	cp -r platforms build
	cp -r *.pxi build
	cython build/pytrie.pyx
	cp build/pytrie.c .
	
build/pytrie.pyx: pytrie.pyx
	gpp -o build/pytrie.pyx pytrie.pyx
	
clean:
	rm -rf build
	rm -f pytrie.c pytrie.so
	mkdir build
