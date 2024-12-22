import Foundation
import PackagePlugin

@main
struct GenerateVersionBuildPlugin: BuildToolPlugin {
  func createBuildCommands(
    context: PackagePlugin.PluginContext,
    target: PackagePlugin.Target
  ) async throws -> [PackagePlugin.Command] {
    guard let target = target as? SwiftSourceModuleTarget else { return [] }

    let gitDirectoryPath = target.directoryURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()

    let tool = try context.tool(named: "cli-version")
    let outputPath = context.pluginWorkDirectoryURL

    let outputFile = outputPath.appending(path: "Version.swift")

    return [
      .buildCommand(
        displayName: "Build with Version Plugin",
        executable: tool.url,
        arguments: [
          "build", "--verbose",
          "--git-directory", gitDirectoryPath.absoluteString,
          "--target", outputPath.absoluteString
        ],
        environment: [:],
        inputFiles: target.sourceFiles.map(\.url),
        outputFiles: [outputFile]
      )
    ]
  }
}
