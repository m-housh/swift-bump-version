import ArgumentParser
import CliClient
import Dependencies

struct BumpCommand: AsyncParsableCommand {

  static let configuration = CommandConfiguration(
    commandName: "bump",
    abstract: "Bump version of a command-line tool."
  )

  @OptionGroup var globals: GlobalOptions

  @Flag(
    help: """
    The semvar bump option, this is ignored if the configuration is set to use a branch/commit sha strategy.
    """
  )
  var bumpOption: CliClient.BumpOption = .patch

  func run() async throws {
    try await globals.run(\.bump, args: bumpOption)
  }
}

extension CliClient.BumpOption: EnumerableFlag {}
