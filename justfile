product := "bump-version"
docker_image := "bump-version"
docker_tag := "test"

tap_url := "https://git.housh.dev/michael/homebrew-formula"
tap := "michael/formula"
formula := "bump-version"
release_base_url := "https://git.housh.dev/michael/bump-version/archive"

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

alias b := build

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

alias cb := clean-build

# Test locally.
test *ARGS:
  @swift test {{ARGS}}

# Build docker test container and run tests.
test-docker: build-docker
  @docker run --rm {{docker_image}}:{{docker_tag}}

test-docker-without-building:
  @docker run --rm {{docker_image}}:{{docker_tag}} swift test

# Get the sha256 sum of the release and copy to clipboard.
get-release-sha prefix="": (build "release")
  version=$(.build/release/hpa --version) && \
    url="{{release_base_url}}/{{prefix}}${version}.tar.gz" && \
    sha=$(curl "$url" | shasum -a 256) && \
    stripped="${sha% *}" && \
    echo "$stripped" | pbcopy && \
    echo "Copied sha to clipboard: $stripped"
