import ArgumentParser
import CliClient
import CliDoc
import Dependencies
import Foundation
import ShellClient

struct GenerateCommand: AsyncParsableCommand {
  static let commandName = "generate"

  static let configuration: CommandConfiguration = .init(
    commandName: Self.commandName,
    abstract: Abstract.default("Generates a version file in your project.").render(),
    usage: Usage.default(commandName: Self.commandName),
    discussion: Discussion {
      "This command can be interacted with directly, outside of the plugin usage context."
    }
  )

  @OptionGroup var globals: GlobalOptions

  func run() async throws {
    try await globals.run(\.generate, command: Self.commandName)
  }
}
