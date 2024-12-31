// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "swift-cli-version",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "bump-version", targets: ["BumpVersion"]),
    .library(name: "CliClient", targets: ["CliClient"]),
    .library(name: "ConfigurationClient", targets: ["ConfigurationClient"]),
    .library(name: "FileClient", targets: ["FileClient"]),
    .library(name: "GitClient", targets: ["GitClient"]),
    .library(name: "LoggingExtensions", targets: ["LoggingExtensions"]),
    .plugin(name: "BuildWithVersionPlugin", targets: ["BuildWithVersionPlugin"]),
    .plugin(name: "BumpVersionPlugin", targets: ["BumpVersionPlugin"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.6.2"),
    .package(url: "https://github.com/m-housh/swift-shell-client.git", from: "0.2.2"),
    .package(url: "https://github.com/m-housh/swift-cli-doc.git", from: "0.2.1"),
    .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump.git", from: "1.3.3")
  ],
  targets: [
    .executableTarget(
      name: "BumpVersion",
      dependencies: [
        "CliClient",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "CliDoc", package: "swift-cli-doc")
      ]
    ),
    .target(
      name: "CliClient",
      dependencies: [
        "ConfigurationClient",
        "FileClient",
        "GitClient",
        "LoggingExtensions",
        .product(name: "Logging", package: "swift-log"),
        .product(name: "CustomDump", package: "swift-custom-dump")
      ]
    ),
    .testTarget(
      name: "CliVersionTests",
      dependencies: ["CliClient", "TestSupport"]
    ),
    .target(
      name: "ConfigurationClient",
      dependencies: [
        "FileClient",
        "LoggingExtensions",
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies")
      ]
    ),
    .testTarget(
      name: "ConfigurationClientTests",
      dependencies: ["ConfigurationClient", "TestSupport"]
    ),
    .target(
      name: "FileClient",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies")
      ]
    ),
    .target(
      name: "GitClient",
      dependencies: [
        "FileClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "ShellClient", package: "swift-shell-client")
      ]
    ),
    .testTarget(
      name: "GitClientTests",
      dependencies: ["GitClient"]
    ),
    .target(
      name: "LoggingExtensions",
      dependencies: [
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "ShellClient", package: "swift-shell-client")
      ]
    ),
    .target(name: "TestSupport"),
    .plugin(
      name: "BuildWithVersionPlugin",
      capability: .buildTool(),
      dependencies: [
        "BumpVersion"
      ]
    ),
    .plugin(
      name: "BumpVersionPlugin",
      capability: .command(
        intent: .custom(
          verb: "bump-version",
          description: "Bumps a version file in the given target."
        ),
        permissions: [
          .writeToPackageDirectory(reason: "Update a version file in the target's directory.")
        ]
      ),
      dependencies: [
        "BumpVersion"
      ]
    )
  ]
)
