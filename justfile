product := "bump-version"
docker_image := "bump-version"
docker_tag := "test"

tap_url := "https://git.housh.dev/michael/homebrew-formula"
tap := "michael/formula"
formula := "bump-version"
release_base_url := "https://git.housh.dev/michael/swift-bump-version/archive"
version := "$(git describe --tags --exact-match)"

[private]
default:
  @just --list

# Build and bottle homebrew formula.
bottle:
  @brew uninstall {{formula}} || true
  @brew tap {{tap}} {{tap_url}}
  @brew install --build-bottle {{tap}}/{{formula}}
  @brew bottle {{formula}}
  bottle="$(ls *.gz)" && mv "${bottle}" "${bottle/--/-}"

# Build locally.
build configuration="debug":
  @swift build \
    --disable-sandbox \
    --configuration {{configuration}} \
    --product {{product}}

# Bump our version of the command-line tool.
bump-version *ARGS: (run "bump" ARGS)

# Build a docker image.
build-docker configuration="debug":
  @docker build -t {{docker_image}}:{{docker_tag}} .

# Run the command-line tool.
run *ARGS:
  @swift run {{product}} {{ARGS}}

# Clean the build folder.
clean:
  rm -rf .build

# Clean and build.
clean-build configuration="debug": clean (build configuration)

# Remove bottles
remove-bottles:
  rm -rf *.gz

# Test locally.
test *ARGS:
  @swift test {{ARGS}}

# Build docker test container and run tests.
test-docker: build-docker
  @docker run --rm {{docker_image}}:{{docker_tag}}

# Run tests in docker without building a new image.
test-docker-without-building:
  @docker run --rm {{docker_image}}:{{docker_tag}} swift test

# Show the current git-tag version.
echo-version:
  @echo "VERSION: {{version}}"

# Get the sha256 sum of the release and copy to clipboard.
get-release-sha prefix="": (build "release")
  url="{{release_base_url}}/{{prefix}}${version}.tar.gz" && \
    sha=$(curl "$url" | shasum -a 256) && \
    stripped="${sha% *}" && \
    echo "$stripped" | pbcopy && \
    echo "Copied sha to clipboard: $stripped"

# Preview the documentation locally.
preview-documentation target="BumpVersion":
	swift package \
		--disable-sandbox \
		preview-documentation \
		--target {{target}}

# Preview the documentation locally.
build-documentation dir="./docs" target="BumpVersion" basePath="bump-version":
	swift package \
		--allow-writing-to-directory {{dir}} \
		generate-documentation \
		--target {{target}} \
		--disable-indexing \
		--transform-for-static-hosting \
		--hosting-base-path {{basePath}} \
		--output-path {{dir}}
