product := "cli-version"

[private]
default:
  @just --list

build configuration="release":
  @swift build \
    --disable-sandbox \
    --configuration {{configuration}} \
    --product {{product}}

run *ARGS:
  @swift run {{product}} {{ARGS}}

clean:
  rm -rf .build

test *ARGS:
  @swift test {{ARGS}}
