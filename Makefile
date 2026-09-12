.PHONY: build run release test demo check-demo

build:
	./scripts/build.sh

run: build
	open dist/Fruitfly.app

release:
	./scripts/build.sh --universal

test:
	swift run -c release FlyChecks

demo:
	./scripts/record-demo.sh

check-demo:
	./scripts/check-demo.sh
