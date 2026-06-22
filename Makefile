all: build

clean:
	rm -rf build

prepare:
	mkdir -p build

build: clean prepare
	sbcl --load build.lisp
