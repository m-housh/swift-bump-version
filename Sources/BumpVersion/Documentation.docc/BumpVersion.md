# ``BumpVersion``

@Metadata {
    @DisplayName("bump-version")
    @DocumentationExtension(mergeBehavior: override)
}

A command-line tool for managing swift application versions.

## Overview

This tool aims to provide a way to manage application versions in your build
pipeline.  It can be used as a stand-alone command-line tool or by using one of
the provided swift package plugins.

## Installation

The command-line tool can be installed via homebrew.

```bash
brew tap m-housh/formula
brew install bump-version
```

## Package Plugins

Package plugins can be used in a swift package manager project.

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

> See Also: <doc:PluginsReference>

## Topics

### Articles

- <doc:BasicConfiguration>
- <doc:ConfigurationReference>
- <doc:CommandReference>
- <doc:OptionsReference>
- <doc:PluginsReference>
