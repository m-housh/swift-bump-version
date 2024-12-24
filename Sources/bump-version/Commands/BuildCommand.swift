import ArgumentParser
import CliClient
import Foundation
import ShellClient

struct BuildCommand: AsyncParsableCommand {
  static let configuration: CommandConfiguration = .init(
    commandName: "build",
    abstract: "Used for the build with version plugin.",
    discussion: "This should generally not be interacted with directly, outside of the build plugin.",
    shouldDisplay: false
  )

  @OptionGroup var globals: GlobalOptions

  func run() async throws {
    try await globals.run(\.build)
  }
}
