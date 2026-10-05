all: build

BUILD_SUFFIX ?=
REQUIRE_NODE ?=

dev-start:
	nohup ./build/lisper > /tmp/lisper.log 2>&1 &

dev-stop:
	-pkill -f ./build/lisper

clean:
	rm -rf build

prepare:
	mkdir -p build

embed-resources:
	REQUIRE_NODE=$(REQUIRE_NODE) sbcl --load build-resources.lisp

build: clean prepare dev-stop embed-resources
	sleep 3
	sbcl --load build.lisp

# Build inside the container (prod/Container.stage1): same as build, but no
# pkill of a host process (dev-stop) and the artifacts land in
# build/lisper$(BUILD_SUFFIX) so the stage2 runtime image can pick it up.
# REQUIRE_NODE=1 makes a missing node fatal instead of silently producing an
# image with an empty JS bundle table (REPL/games/markdown would be broken).
container-build: clean prepare embed-resources
	BUILD_SUFFIX=$(BUILD_SUFFIX) sbcl --load build.lisp
