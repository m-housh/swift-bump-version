import ArgumentParser
import CliClient
import Foundation
import ShellClient

extension CliVersionCommand {
  struct Build: AsyncParsableCommand {
    static let configuration: CommandConfiguration = .init(
      abstract: "Used for the build with version plugin.",
      discussion: "This should generally not be interacted with directly, outside of the build plugin.",
      subcommands: [BranchStyle.self, SemVarStyle.self],
      defaultSubcommand: SemVarStyle.self
    )
  }
}

extension CliVersionCommand.Build {
  struct BranchStyle: AsyncParsableCommand {

    static let configuration: CommandConfiguration = .init(
      commandName: "branch",
      abstract: "Build using branch and commit sha as the version.",
      discussion: "This should generally not be interacted with directly, outside of the plugin usage context."
    )

    @OptionGroup var globals: GlobalBranchOptions

    func run() async throws {
      try await globals.shared().run(\.build)
    }
  }

  struct SemVarStyle: AsyncParsableCommand {

    static let configuration: CommandConfiguration = .init(
      commandName: "semvar",
      abstract: "Generates a version file with SemVar style.",
      discussion: "This should generally not be interacted with directly, outside of the plugin usage context."
    )

    @OptionGroup var globals: GlobalSemVarOptions

    func run() async throws {
      try await globals.shared().run(\.build)
    }
  }
}
