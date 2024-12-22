import ArgumentParser
import CliClient
import Dependencies
import Foundation
import ShellClient

extension CliVersionCommand {
  struct Generate: AsyncParsableCommand {
    static let configuration: CommandConfiguration = .init(
      abstract: "Generates a version file in a command line tool that can be set via the git tag or git sha.",
      discussion: "This command can be interacted with directly, outside of the plugin usage context.",
      version: VERSION ?? "0.0.0"
    )

    @OptionGroup var globals: GlobalOptions

    func run() async throws {
      try await globals.run {
        @Dependency(\.cliClient) var cliClient
        let output = try await cliClient.generate(globals.shared)
        print(output)
      }
    }
  }
}

private enum GenerationError: Error {
  case fileExists(path: String)
}
