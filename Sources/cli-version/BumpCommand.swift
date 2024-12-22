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

    @Flag
    var bumpOption: CliClient.BumpOption = .patch

    func run() async throws {
      try await globals.run {
        @Dependency(\.cliClient) var cliClient
        let output = try await cliClient.bump(bumpOption, globals.shared)
        print(output)
      }
    }
  }
}

extension CliClient.BumpOption: EnumerableFlag {}
