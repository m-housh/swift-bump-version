import ConfigurationClient
import Dependencies
import DependenciesMacros
import FileClient
import Foundation
import GitClient
import LoggingExtensions
import ShellClient

public extension DependencyValues {

  /// The cli-client that runs the command line tool commands.
  var cliClient: CliClient {
    get { self[CliClient.self] }
    set { self[CliClient.self] = newValue }
  }
}

/// Handles the command-line commands.
@DependencyClient
public struct CliClient: Sendable {

  /// Build and update the version based on the git tag, or branch + sha.
  public var build: @Sendable (SharedOptions) async throws -> String

  /// Bump the existing version.
  public var bump: @Sendable (BumpOption?, SharedOptions) async throws -> String

  /// Generate a version file with an optional version that can be set manually.
  public var generate: @Sendable (SharedOptions) async throws -> String

  /// Parse the configuration options.
  public var parsedConfiguration: @Sendable (SharedOptions) async throws -> Configuration

  public enum BumpOption: Sendable, CaseIterable {
    case major, minor, patch, preRelease
  }

  /// Represents options that are used by all the commands.
  public struct SharedOptions: Equatable, Sendable {

    /// Whether to allow pre-release suffixes.
    let allowPreReleaseTag: Bool

    /// Flag on if we write to files or not.
    let dryRun: Bool

    /// Specify a path to the project directory.
    let projectDirectory: String?

    /// The logging options to use.
    let loggingOptions: LoggingOptions

    /// Configuration that gets merged with the loaded (or default) configuration.
    let configurationToMerge: Configuration?

    /// Path to the configuration file to load.
    let configurationFile: String?

    /// Fail if a configuration file is not found.
    let requireConfigurationFile: Bool

    public init(
      allowPreReleaseTag: Bool = true,
      dryRun: Bool = false,
      projectDirectory: String? = nil,
      loggingOptions: LoggingOptions,
      configurationToMerge: Configuration? = nil,
      configurationFile: String? = nil,
      requireConfigurationFile: Bool = false
    ) {
      self.allowPreReleaseTag = allowPreReleaseTag
      self.dryRun = dryRun
      self.projectDirectory = projectDirectory
      self.loggingOptions = loggingOptions
      self.configurationFile = configurationFile
      self.configurationToMerge = configurationToMerge
      self.requireConfigurationFile = requireConfigurationFile
    }
  }

}

extension CliClient: DependencyKey {

  public static let testValue: CliClient = Self()

  public static func live(environment: [String: String]) -> Self {
    .init(
      build: { try await $0.build(environment) },
      bump: { try await $1.bump($0) },
      generate: { try await $0.generate() },
      parsedConfiguration: { options in
        try await options.loggingOptions.withLogger {
          try await options.withMergedConfiguration { $0 }
        }
      }
    )
  }

  public static var liveValue: CliClient {
    .live(environment: ProcessInfo.processInfo.environment)
  }
}
