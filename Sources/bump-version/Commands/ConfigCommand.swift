import ArgumentParser
import CliClient
import ConfigurationClient
import CustomDump
import Dependencies
import FileClient
import Foundation

struct ConfigCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "config",
    abstract: "Configuration commands",
    subcommands: [
      DumpConfig.self,
      GenerateConfig.self
    ]
  )
}

extension ConfigCommand {

  struct DumpConfig: AsyncParsableCommand {
    static let commandName = "dump"

    static let configuration = CommandConfiguration(
      commandName: Self.commandName,
      abstract: "Inspect the parsed configuration.",
      discussion: """
      This will load any configuration and merge the options passed in. Then print it to stdout.
      The default style is to print the output in `swift`, however you can use the `--print` flag to
      print the output in `json`.
      """,
      aliases: ["d"]
    )

    @OptionGroup var globals: ConfigCommandOptions

    func run() async throws {
      let configuration = try await globals
        .shared(command: Self.commandName)
        .runClient(\.parsedConfiguration)

      try globals.printConfiguration(configuration)
    }
  }

  struct GenerateConfig: AsyncParsableCommand {
    static let configuration: CommandConfiguration = .init(
      commandName: "generate",
      abstract: "Generate a configuration file.",
      aliases: ["g"]
    )

    @Flag(
      help: "The style of the configuration."
    )
    var style: ConfigCommand.Style = .semvar

    @OptionGroup var globals: ConfigCommandOptions

    func run() async throws {
      try await withSetupDependencies {
        @Dependency(\.configurationClient) var configurationClient

        let configuration = try style.parseConfiguration(
          configOptions: globals.configOptions,
          extraOptions: globals.extraOptions
        )

        switch globals.printJson {
        case true:
          try globals.handlePrintJson(configuration)
        case false:
          let url = globals.configFileUrl
          try await configurationClient.write(configuration, url)
          print(url.cleanFilePath)
        }
      }
    }

  }
}

extension ConfigCommand {
  enum Style: EnumerableFlag {
    case branch, semvar

    func parseConfiguration(
      configOptions: ConfigurationOptions,
      extraOptions: [String]
    ) throws -> Configuration {
      let strategy: Configuration.VersionStrategy

      switch self {
      case .branch:
        strategy = .branch(includeCommitSha: configOptions.commitSha)
      case .semvar:
        strategy = try .semvar(configOptions.semvarOptions(extraOptions: extraOptions))
      }

      return try Configuration(
        target: configOptions.target(),
        strategy: strategy
      )
    }
  }

  // TODO: Add verbose.
  @dynamicMemberLookup
  struct ConfigCommandOptions: ParsableArguments {

    @Flag(
      name: .customLong("print"),
      help: "Print style to stdout."
    )
    var printJson: Bool = false

    @OptionGroup var configOptions: ConfigurationOptions

    @Argument(
      help: """
      Arguments / options used for custom pre-release, options / flags must proceed a '--' in
      the command. These are ignored if the `--custom-command` or `--custom-pre-release` flag is not set.
      """
    )
    var extraOptions: [String] = []

    subscript<T>(dynamicMember keyPath: KeyPath<ConfigurationOptions, T>) -> T {
      configOptions[keyPath: keyPath]
    }
  }
}

private extension ConfigCommand.ConfigCommandOptions {

  func shared(command: String) throws -> CliClient.SharedOptions {
    try configOptions.shared(command: command, extraOptions: extraOptions, verbose: 2)
  }

  func handlePrintJson(_ configuration: Configuration) throws {
    @Dependency(\.coders) var coders
    @Dependency(\.logger) var logger

    let data = try coders.jsonEncoder().encode(configuration)
    guard let string = String(bytes: data, encoding: .utf8) else {
      logger.error("Error encoding configuration to json.")
      throw ConfigurationEncodingError()
    }
    print(string)
  }

  func printConfiguration(_ configuration: Configuration) throws {
    guard printJson else {
      customDump(configuration)
      return
    }
    try handlePrintJson(configuration)
  }
}

private extension ConfigurationOptions {
  var configFileUrl: URL {
    switch configurationFile {
    case let .some(path):
      return URL(filePath: path)
    case .none:
      return URL(filePath: ".bump-version.json")
    }
  }
}

struct ConfigurationEncodingError: Error {}
