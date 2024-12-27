# Plugins Reference

Learn about using the provided package plugins.

## Overview

There are two provided plugins that can be used, this describes their usage.

### Build with Version

The `BuildWithVersion` plugin uses your project configuration to automatically generate a version
file when swift builds your project. You can use the plugin by declaring it as dependency in your
project.

```swift
// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  platforms:[.macOS(.v13)],
  dependencies: [
    ...,
    .package(url: "https://github.com/m-housh/swift-bump-version.git", from: "0.2.0")
  ],
  targets: [
    .executableTarget(
      name: "<target name>",
      dependencies: [...],
      plugins: [
        .plugin(name: "BuildWithVersionPlugin", package: "swift-bump-version")
      ]
    )
  ]
)
```

### Manual Plugin

There is also a `BumpVersionPlugin` that allows you to run the `bump-version` tool without
installing the command-line tool on your system, however it does make the usage much more verbose.

Include as dependency in your project.

```swift
// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  platforms:[.macOS(.v13)],
  dependencies: [
    ...,
    .package(url: "https://github.com/m-housh/swift-bump-version.git", from: "0.2.0")
  ],
  targets: [
    ...
  ]
)
```

Then you can use the manual plugin.

```
swift package \
  --disable-sandbox \
  --allow-writing-to-package-directory \
  bump-version \
  bump \
  --minor
```

> Note: Anything after the `'bump-version'` in the above get's passed directly to the bump-version
> command-line tool, so you can use this to run any of the provided commands, the above shows
> bumping the minor semvar as a reference example.
>
> See Also: <doc:CommandReference>
