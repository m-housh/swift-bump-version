PLATFORM_MACOS = macOS
CONFIG := debug
DOCC_TARGET ?= CliVersion
DOCC_BASEPATH = $(shell basename "$(PWD)")
DOCC_DIR ?= ./docs

clean:
	rm -rf .build

build-documentation:
	swift package \
		--allow-writing-to-directory "$(DOCC_DIR)" \
		generate-documentation \
		--target "$(DOCC_TARGET)" \
		--disable-indexing \
		--transform-for-static-hosting \
		--hosting-base-path "$(DOCC_BASEPATH)" \
		--output-path "$(DOCC_DIR)"

preview-documentation:
	swift package \
		--disable-sandbox \
		preview-documentation \
		--target "$(DOCC_TARGET)"

test-linux:
	docker run --rm \
		--volume "$(PWD):$(PWD)" \
		--workdir "$(PWD)" \
		swift:5.7-focal \
		swift test

test-library:
	swift test -c $(CONFIG)

update-version:
	swift package \
		--disable-sandbox \
		--allow-writing-to-package-directory \
		update-version \
		git-version

