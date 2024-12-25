import ArgumentParser
import CliClient
import Dependencies
import Foundation
import ShellClient

struct GenerateCommand: AsyncParsableCommand {
  static let commandName = "generate"

  static let configuration: CommandConfiguration = .init(
    commandName: Self.commandName,
    abstract: "Generates a version file in a command line tool that can be set via the git tag or git sha.",
    discussion: "This command can be interacted with directly, outside of the plugin usage context."
  )

  @OptionGroup var globals: GlobalOptions

  func run() async throws {
    try await globals.run(\.generate, command: Self.commandName)
  }
}
