import ArgumentParser
import CliClient
import Dependencies
import Foundation
import ShellClient

extension CliVersionCommand {

  struct Update: AsyncParsableCommand {
    static let configuration: CommandConfiguration = .init(
      abstract: "Updates a version string to the git tag or git sha.",
      discussion: "This command can be interacted with directly outside of the plugin context."
    )

    @OptionGroup var globals: GlobalOptions

    func run() async throws {
      try await globals.run {
        @Dependency(\.cliClient) var cliClient
        let output = try await cliClient.update(globals.shared)
        print(output)
      }
    }
  }
}

private enum UpdateError: Error {
  case versionFileDoesNotExist(path: String)
}
