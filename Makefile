test: pytrie.so
	time python work.py

pytrie.so: pytrie.c
	gcc -shared -pthread -fPIC -fwrapv -O3 -Wall -fno-strict-aliasing -I/usr/local/include/python2.6 -o pytrie.so pytrie.c
	
pytrie.c: pytrie.pyx
	cython pytrie.pyx
	
clean:
	rm pytrie.c pytrie.so
