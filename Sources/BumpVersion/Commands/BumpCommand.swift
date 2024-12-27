import ArgumentParser
import CliClient
import CliDoc
import Dependencies

struct BumpCommand: CommandRepresentable {

  static let commandName = "bump"

  static let configuration = CommandConfiguration(
    commandName: Self.commandName,
    abstract: Abstract.default("Bump version of a command-line tool."),
    usage: Usage.default(commandName: nil),
    discussion: Discussion.default(examples: [
      makeExample(
        label: "Basic usage, bump the minor version.",
        example: "--minor"
      ),
      makeExample(
        label: "Dry run, just show what the bumped version would be.",
        example: "--minor --print"
      )
    ])
  )

  @OptionGroup var globals: GlobalOptions

  @Flag(
    help: """
    The semvar bump option, this is ignored if the configuration is set to use a branch/commit sha strategy.
    """
  )
  var bumpOption: CliClient.BumpOption = .patch

  func run() async throws {
    try await globals.run(\.bump, command: Self.commandName, args: bumpOption)
  }
}

extension CliClient.BumpOption: EnumerableFlag {}
