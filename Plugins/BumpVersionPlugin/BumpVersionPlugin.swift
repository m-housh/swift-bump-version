import Foundation
import PackagePlugin

@main
struct BumpVersionPlugin: CommandPlugin {

  func performCommand(context: PluginContext, arguments: [String]) async throws {
    print("Starting bump-version plugin")
    let tool = try context.tool(named: "bump-version")

    print("arguments: \(arguments)")

    let process = Process()
    process.executableURL = tool.url
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()

    guard process.terminationReason == .exit && process.terminationStatus == 0 else {
      Diagnostics.error("Reason: \(process.terminationReason), status: \(process.terminationStatus)")
      return
    }
  }
}
