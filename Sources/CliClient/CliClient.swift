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

  public struct SharedOptions: Equatable, Sendable {

    let allowPreReleaseTag: Bool
    let dryRun: Bool
    let gitDirectory: String?
    let loggingOptions: LoggingOptions
    let target: Configuration.Target?
    let branch: Configuration.Branch?
    let semvar: Configuration.SemVar?
    let configurationFile: String?

    public init(
      allowPreReleaseTag: Bool = true,
      dryRun: Bool = false,
      gitDirectory: String? = nil,
      loggingOptions: LoggingOptions,
      target: Configuration.Target? = nil,
      branch: Configuration.Branch? = nil,
      semvar: Configuration.SemVar? = nil,
      configurationFile: String? = nil
    ) {
      self.allowPreReleaseTag = allowPreReleaseTag
      self.dryRun = dryRun
      self.gitDirectory = gitDirectory
      self.loggingOptions = loggingOptions
      self.target = target
      self.branch = branch
      self.semvar = semvar
      self.configurationFile = configurationFile
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
