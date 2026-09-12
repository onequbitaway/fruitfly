.PHONY: build run release test

build:
	./scripts/build.sh

run: build
	open dist/Fruitfly.app

release:
	./scripts/build.sh --universal

test:
	swift run -c release FlyChecks
