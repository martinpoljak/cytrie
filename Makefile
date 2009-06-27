test: pytrie.so
	time python work.py

pytrie.so: pytrie.pyx
	python setup.py build
	cp build/lib.freebsd-7.2-RELEASE-i386-2.6/pytrie.so .
