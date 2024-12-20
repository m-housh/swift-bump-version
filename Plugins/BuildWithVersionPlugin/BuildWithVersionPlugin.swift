import Foundation
import PackagePlugin

@main
struct GenerateVersionBuildPlugin: BuildToolPlugin {
  func createBuildCommands(
    context: PackagePlugin.PluginContext,
    target: PackagePlugin.Target
  ) async throws -> [PackagePlugin.Command] {
    guard let target = target as? SourceModuleTarget else { return [] }

    let gitDirectoryPath = target.directory
      .removingLastComponent()
      .removingLastComponent()

    let tool = try context.tool(named: "cli-version")
    let outputPath = context.pluginWorkDirectory

    let outputFile = outputPath.appending("Version.swift")

    return [
      .buildCommand(
        displayName: "Build With Version Plugin",
        executable: tool.path,
        arguments: ["build", "--verbose", "--git-directory", gitDirectoryPath.string, outputPath.string],
        environment: [:],
        inputFiles: target.sourceFiles.map(\.path),
        outputFiles: [outputFile]
      )
    ]
  }
}
