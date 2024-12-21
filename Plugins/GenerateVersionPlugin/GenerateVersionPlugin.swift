import Foundation
import PackagePlugin

@main
struct GenerateVersionPlugin: CommandPlugin {

  func performCommand(context: PluginContext, arguments: [String]) async throws {
    let gitVersion = try context.tool(named: "cli-version")

    let arguments = ["generate"] + arguments

    for target in context.package.targets {
      guard let target = target as? SourceModuleTarget,
            arguments.first(where: { $0.contains(target.name) }) != nil
      else { continue }

      let process = Process()
      process.executableURL = URL(fileURLWithPath: gitVersion.path.string)
      process.arguments = arguments
      try process.run()
      process.waitUntilExit()

      guard process.terminationReason == .exit && process.terminationStatus == 0 else {
        Diagnostics.error("Reason: \(process.terminationReason), status: \(process.terminationStatus)")
        return
      }
    }
  }
}
