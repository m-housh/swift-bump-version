product := "cli-version"
docker_image := "cli-version"
docker_tag := "test"

[private]
default:
  @just --list

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
