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

.PHONY: preview preview-build preview-release preview-test preview-ui-check preview-demo desktop-demo

preview: preview-build
	open 'dist/Fruitfly Preview.app'

preview-build:
	./experiments/full-map/scripts/build.sh

preview-release:
	./experiments/full-map/scripts/build.sh --universal

preview-test:
	./experiments/full-map/scripts/fetch-data.sh
	swift run -c release --package-path experiments/full-map BrainChecks experiments/full-map/Data

preview-ui-check: preview-build
	'dist/Fruitfly Preview.app/Contents/MacOS/FruitflyBrainPreview' --smoke-tests

preview-demo: preview-build
	'dist/Fruitfly Preview.app/Contents/MacOS/FruitflyBrainPreview' --record experiments/full-map/output/brain

desktop-demo: preview-build
	'dist/Fruitfly Preview.app/Contents/MacOS/FruitflyBrainPreview' --record-desktop experiments/full-map/output/desktop --brain-gif docs/media/full-map-activity.gif

.PHONY: royale royale-build royale-release royale-test royale-test-full royale-demo

royale: royale-build
	open 'dist/Fruitfly Royale.app'

royale-build:
	./experiments/royale/scripts/build.sh

royale-release:
	./experiments/royale/scripts/build.sh --universal

royale-test:
	./experiments/full-map/scripts/fetch-data.sh
	swift run -c release --package-path experiments/royale RoyaleChecks experiments/full-map/Data

royale-test-full:
	./experiments/full-map/scripts/fetch-data.sh
	swift run -c release --package-path experiments/royale RoyaleChecks experiments/full-map/Data --full

royale-demo: royale-build
	'dist/Fruitfly Royale.app/Contents/MacOS/FruitflyRoyale' --record experiments/royale/output/full --full

.PHONY: duel duel-build duel-release duel-test duel-test-full duel-demo

duel: duel-build
	open 'dist/Fruitfly Duel.app'

duel-build:
	./experiments/duel/scripts/build.sh

duel-release:
	./experiments/duel/scripts/build.sh --universal

duel-test:
	./experiments/full-map/scripts/fetch-data.sh
	swift run -c release --package-path experiments/duel DuelChecks experiments/full-map/Data

duel-test-full:
	./experiments/full-map/scripts/fetch-data.sh
	swift run -c release --package-path experiments/duel DuelChecks experiments/full-map/Data --full

duel-demo: duel-build
	'dist/Fruitfly Duel.app/Contents/MacOS/FruitflyDuel' --record experiments/duel/output/full
