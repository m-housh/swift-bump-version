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
      DumpConfig.self,
      GenerateConfig.self
    ]
  )
}

extension UtilsCommand {
  struct DumpConfig: AsyncParsableCommand {
    static let commandName = "dump-config"

    static let configuration = CommandConfiguration(
      commandName: Self.commandName,
      abstract: "Show the parsed configuration.",
      aliases: ["dc"]
    )

    @OptionGroup var globals: GlobalOptions

    func run() async throws {
      let configuration = try await globals.runClient(\.parsedConfiguration, command: Self.commandName)
      customDump(configuration)
    }
  }

  struct GenerateConfig: AsyncParsableCommand {
    static let configuration: CommandConfiguration = .init(
      commandName: "generate-config",
      abstract: "Generate a configuration file.",
      aliases: ["gc"]
    )

    @OptionGroup var configOptions: ConfigurationOptions

    @Flag(
      help: "The style of the configuration."
    )
    var style: Style = .semvar

    @Argument(
      help: """
      Arguments / options used for custom pre-release, options / flags must proceed a '--' in
      the command. These are ignored if the `--custom` flag is not set.
      """
    )
    var extraOptions: [String] = []

    func run() async throws {
      try await withSetupDependencies {
        @Dependency(\.configurationClient) var configurationClient

        let strategy: Configuration.VersionStrategy

        switch style {
        case .branch:
          strategy = .branch(includeCommitSha: configOptions.commitSha)
        case .semvar:
          strategy = try .semvar(configOptions.semvarOptions(extraOptions: extraOptions))
        }

        let configuration = try Configuration(
          target: configOptions.target(),
          strategy: strategy
        )

        let url: URL
        switch configOptions.configurationFile {
        case let .some(path):
          url = URL(filePath: path)
        case .none:
          url = URL(filePath: ".bump-version.json")
        }

        try await configurationClient.write(configuration, url)

        print(url.cleanFilePath)
      }
    }
  }
}

extension UtilsCommand.GenerateConfig {
  enum Style: EnumerableFlag {
    case branch, semvar
  }
}
