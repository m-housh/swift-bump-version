import ArgumentParser
import ConfigurationClient
import CustomDump
import Dependencies
import FileClient
import Foundation

struct UtilsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "utils",
    abstract: "Utility commands",
    subcommands: [
      DumpConfig.self
    ]
  )
}

extension UtilsCommand {
  struct DumpConfig: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "dump-config",
      abstract: "Show the parsed configuration."
    )

    @Argument(
      help: """
      Optional path to the configuration file, if not supplied will search the current directory
      """,
      completion: .file(extensions: ["toml", "json"])
    )
    var file: String?

    func run() async throws {
      try await withDependencies {
        $0.fileClient = .liveValue
        $0.configurationClient = .liveValue
      } operation: {
        @Dependency(\.configurationClient) var configurationClient

        let configuration = try await configurationClient.findAndLoad(
          file != nil ? URL(filePath: file!) : nil
        )

        customDump(configuration)
      }
    }
  }
}
