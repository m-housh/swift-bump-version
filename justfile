
build configuration="release":
  @swift build --configuration {{configuration}}

run *ARGS:
  @swift run cli-version {{ARGS}}

clean:
  rm -rf .build
