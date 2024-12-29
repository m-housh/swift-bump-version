import ArgumentParser
import CliClient
import CliDoc
import ConfigurationClient
import CustomDump
import Dependencies
import FileClient
import Foundation

struct ConfigCommand: AsyncParsableCommand {
  static let commandName = "config"

  static let configuration = CommandConfiguration(
    commandName: commandName,
    abstract: Abstract.default("Configuration commands").render(),
    subcommands: [
      DumpConfig.self,
      GenerateConfig.self
    ]
  )
}

extension ConfigCommand {

  struct DumpConfig: CommandRepresentable {
    static let commandName = "dump"
    static let parentCommand = ConfigCommand.commandName

    static let configuration = CommandConfiguration(
      commandName: Self.commandName,
      abstract: Abstract.default("Inspect the parsed configuration."),
      usage: Usage.default(parentCommand: ConfigCommand.commandName, commandName: Self.commandName),
      discussion: Discussion.default(
        notes: [
          """
          The default style is to print the output in `json`, however you can use the `--swift` flag to
          print the output in `swift`.
          """
        ],
        examples: [
          makeExample(label: "Show the project configuration.", example: ""),
          makeExample(
            label: "Update a configuration file with the dumped output",
            example: "--disable-pre-release > .bump-version.prod.json"
          )
        ]
      ) {
        """
        Loads the project configuration file (if applicable) and merges the options passed in,
        then prints the configuration to stdout.
        """
      },
      aliases: ["d"]
    )
    @Flag(
      help: "Change the style of what get's printed."
    )
    fileprivate var printStyle: PrintStyle = .json

    @OptionGroup var globals: ConfigCommandOptions

    func run() async throws {
      @Dependency(\.logger) var logger
      let configuration = try await globals
        .shared(command: Self.commandName)
        .runClient(\.parsedConfiguration)

      try globals.printConfiguration(configuration, style: printStyle)
    }
  }

  struct GenerateConfig: CommandRepresentable {
    static let commandName = "generate"
    static let parentCommand = ConfigCommand.commandName

    static let configuration: CommandConfiguration = .init(
      commandName: commandName,
      abstract: Abstract.default("Generate a configuration file, based on the given options.").render(),
      usage: Usage.default(parentCommand: ConfigCommand.commandName, commandName: commandName),
      discussion: Discussion.default(examples: [
        makeExample(
          label: "Generate a configuration file for the 'foo' target.",
          example: "-m foo"
        ),
        makeExample(
          label: "Show the output and don't write to a file.",
          example: "-m foo --print"
        )
      ]),
      aliases: ["g"]
    )

    @Flag(
      help: "The style of the configuration."
    )
    var style: ConfigCommand.Style = .semvar

    @Flag(
      name: .customLong("print"),
      help: "Print json to stdout."
    )
    var printJson: Bool = false

    @OptionGroup var globals: ConfigCommandOptions

    func run() async throws {
      try await withSetupDependencies {
        @Dependency(\.configurationClient) var configurationClient

        let configuration = try style.parseConfiguration(
          configOptions: globals.configOptions,
          extraOptions: globals.extraOptions
        )

        switch printJson {
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

  @dynamicMemberLookup
  struct ConfigCommandOptions: ParsableArguments {

    @OptionGroup var configOptions: ConfigurationOptions

    @Flag(
      name: .shortAndLong,
      help: "Increase logging level, can be passed multiple times (example: -vvv)."
    )
    var verbose: Int

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

private extension ConfigCommand.DumpConfig {
  enum PrintStyle: EnumerableFlag {
    case json, swift
  }
}

private extension ConfigCommand.ConfigCommandOptions {

  func shared(command: String) throws -> CliClient.SharedOptions {
    try configOptions.shared(
      command: command,
      extraOptions: extraOptions,
      verbose: verbose
    )
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

  func printConfiguration(
    _ configuration: Configuration,
    style: ConfigCommand.DumpConfig.PrintStyle
  ) throws {
    switch style {
    case .json:
      try handlePrintJson(configuration)
    case .swift:
      customDump(configuration)
    }
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
