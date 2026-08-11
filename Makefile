all: build

dev-start:
	nohup ./build/lisper > /tmp/lisper.log 2>&1 &

dev-stop:
	-pkill -f ./build/lisper

clean:
	rm -rf build

prepare:
	mkdir -p build

embed-resources:
	sbcl --load build-resources.lisp

build: clean prepare dev-stop embed-resources
	sleep 3
	sbcl --load build.lisp
