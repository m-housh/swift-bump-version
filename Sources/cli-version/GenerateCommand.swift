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
      subcommands: [BranchStyle.self, SemVarStyle.self],
      defaultSubcommand: SemVarStyle.self
    )
  }
}

extension CliVersionCommand.Generate {
  struct BranchStyle: AsyncParsableCommand {

    static let configuration: CommandConfiguration = .init(
      commandName: "branch",
      abstract: "Generates a version file with branch and commit sha as the version.",
      discussion: "This command can be interacted with directly, outside of the plugin usage context."
    )

    @OptionGroup var globals: GlobalBranchOptions

    func run() async throws {
      try await globals.shared().run(\.generate)
    }
  }

  struct SemVarStyle: AsyncParsableCommand {

    static let configuration: CommandConfiguration = .init(
      commandName: "semvar",
      abstract: "Generates a version file with SemVar style.",
      discussion: "This command can be interacted with directly, outside of the plugin usage context."
    )

    @OptionGroup var globals: GlobalSemVarOptions

    func run() async throws {
      try await globals.shared().run(\.generate)
    }
  }
}

private enum GenerationError: Error {
  case fileExists(path: String)
}
