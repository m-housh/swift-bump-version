import ArgumentParser
import CliClient
import Foundation
import ShellClient

extension CliVersionCommand {
  struct Build: AsyncParsableCommand {
    static let configuration: CommandConfiguration = .init(
      abstract: "Used for the build with version plugin.",
      discussion: "This should generally not be interacted with directly, outside of the build plugin."
    )

    @OptionGroup var globals: GlobalOptions

    func run() async throws {
      try await globals.run {
        @Dependency(\.cliClient) var cliClient
        let output = try await cliClient.build(globals.shared)
        print(output)
      }
    }
  }
}
