import ArgumentParser
import CliClient
import Dependencies

extension CliVersionCommand {
  struct Bump: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
      commandName: "bump",
      abstract: "Bump version of a command-line tool.",
      subcommands: [
        SemVarStyle.self,
        BranchStyle.self
      ],
      defaultSubcommand: SemVarStyle.self
    )
  }
}

extension CliVersionCommand.Bump {

  struct BranchStyle: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
      commandName: "branch",
      abstract: "Bump using the current branch and commit sha."
    )

    @OptionGroup var globals: GlobalBranchOptions

    func run() async throws {
      try await globals.shared().run(\.bump, args: nil)
    }
  }

  struct SemVarStyle: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
      commandName: "semvar",
      abstract: "Bump using semvar style options."
    )

    @OptionGroup var globals: GlobalSemVarOptions

    @Flag
    var bumpOption: CliClient.BumpOption = .patch

    func run() async throws {
      try await globals.shared().run(\.bump, args: bumpOption)
    }

  }
}

extension CliClient.BumpOption: EnumerableFlag {}
