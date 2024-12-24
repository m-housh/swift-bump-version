import ArgumentParser
import CliClient
import Dependencies

extension CliVersionCommand {
  struct Bump: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
      commandName: "bump",
      abstract: "Bump version of a command-line tool."
    )

    @OptionGroup var globals: GlobalOptions

    func run() async throws {
      try await globals.shared().run(\.bump, args: nil)
    }
  }
}

extension CliClient.BumpOption: EnumerableFlag {}
