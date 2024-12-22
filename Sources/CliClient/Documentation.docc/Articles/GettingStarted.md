# Getting Started

Learn how to integrate the plugins into your project

## Overview

Use the plugins by including as a package to your project and declaring in the `plugins` section of
your target.

> Note: You must use swift-tools version 5.6 or greater for package plugins and
> target `macOS(.v10_15)` or greater.

```swift
// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  platforms:[.macOS(.v10_15)],
  dependencies: [
    ...,
    .package(url: "https://github.com/m-housh/swift-cli-version.git", from: "0.1.0")
  ],
  targets: [
    .executableTarget(
      name: "<target name>",
      dependencies: [...],
      plugins: [ 
        .plugin(name: "BuildWithVersionPlugin", package: "swift-cli-version")
      ]
    )
  ]
)
```

The above example uses the build tool plugin.  The `BuildWithVersionPlugin` will give you access
to a `VERSION` variable in your project that you can use to supply the version of the tool.

### Example

```swift
import ArgumentParser

@main
struct MyCliTool: ParsableCommand { 
  static let configuration = CommandConfiguration(
    abstract: "My awesome cli tool",
    version: VERSION
  )

  func run() throws { 
    print("Version: \(VERSION)")
  }
}
```

After you enable the plugin, you will have access to the `VERSION` string variable even though it is 
not declared in your source files.

![Trust & Enable](trust)

> Note: If your `DerivedData` folder lives in a directory that is a mounted volume / or somewhere
> that is not under your home folder then you may get build failures using the build tool
> plugin, it will work if you build from the command line and pass the `--disable-sandbox` flag to the
> build command or use one of the manual methods.

## See Also

<doc:ManualPlugins>
