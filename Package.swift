// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "swift-cli-version",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(name: "CliClient", targets: ["CliClient"]),
    .plugin(name: "BuildWithVersionPlugin", targets: ["BuildWithVersionPlugin"]),
    .plugin(name: "GenerateVersionPlugin", targets: ["GenerateVersionPlugin"]),
    .plugin(name: "UpdateVersionPlugin", targets: ["UpdateVersionPlugin"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.6.2"),
    .package(url: "https://github.com/m-housh/swift-shell-client.git", from: "0.2.0"),
    .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2")
  ],
  targets: [
    .executableTarget(
      name: "cli-version",
      dependencies: [
        "CliClient",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ]
    ),
    .target(
      name: "CliClient",
      dependencies: [
        "FileClient",
        "GitClient",
        .product(name: "Logging", package: "swift-log")
      ]
    ),
    .testTarget(
      name: "CliVersionTests",
      dependencies: ["CliClient", "TestSupport"]
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
    .target(name: "TestSupport"),
    .plugin(
      name: "BuildWithVersionPlugin",
      capability: .buildTool(),
      dependencies: [
        "cli-version"
      ]
    ),
    .plugin(
      name: "GenerateVersionPlugin",
      capability: .command(
        intent: .custom(
          verb: "generate-version",
          description: "Generates a version file in the given target."
        ),
        permissions: [
          .writeToPackageDirectory(reason: "Generate a version file in the target's directory.")
        ]
      ),
      dependencies: [
        "cli-version"
      ]
    ),
    .plugin(
      name: "UpdateVersionPlugin",
      capability: .command(
        intent: .custom(
          verb: "update-version",
          description: "Updates a version file in the given target."
        ),
        permissions: [
          .writeToPackageDirectory(reason: "Update a version file in the target's directory.")
        ]
      ),
      dependencies: [
        "cli-version"
      ]
    )
  ]
)
