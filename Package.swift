// swift-tools-version: 5.6

import PackageDescription

let package = Package(
  name: "swift-cli-version",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .library(name: "CliVersion", targets: ["CliVersion"]),
    .plugin(name: "BuildWithVersionPlugin", targets: ["BuildWithVersionPlugin"]),
    .plugin(name: "GenerateVersionPlugin", targets: ["GenerateVersionPlugin"]),
    .plugin(name: "UpdateVersionPlugin", targets: ["UpdateVersionPlugin"])
  ],
  dependencies: [
    .package(url: "https://github.com/m-housh/swift-shell-client.git", from: "0.1.3"),
    .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.2")
  ],
  targets: [
    .executableTarget(
      name: "cli-version",
      dependencies: [
        "CliVersion",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ]
    ),
    .target(
      name: "CliVersion",
      dependencies: [
        .product(name: "ShellClient", package: "swift-shell-client")
      ]
    ),
    .testTarget(
      name: "CliVersionTests",
      dependencies: ["CliVersion"]
    ),
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
