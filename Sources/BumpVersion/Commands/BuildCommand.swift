import ArgumentParser
import CliClient
import CliDoc
import Foundation
import ShellClient

// NOTE: This command is only used with the build with version plugin.
struct BuildCommand: AsyncParsableCommand {
  static let commandName = "build"

  static let configuration: CommandConfiguration = .init(
    commandName: Self.commandName,
    abstract: Abstract.default("Used for the build with version plugin.").render(),
    discussion: Discussion {
      "This should generally not be interacted with directly, outside of the build plugin."
    },
    shouldDisplay: false
  )

  @OptionGroup var globals: GlobalOptions

  func run() async throws {
    try await globals.run(\.build, command: Self.commandName)
  }
}
