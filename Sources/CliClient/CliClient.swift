import ConfigurationClient
import Dependencies
import DependenciesMacros
import FileClient
import Foundation
import GitClient
import ShellClient

// TODO: Integrate ConfigurationClient

public extension DependencyValues {

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

  public enum BumpOption: Sendable, CaseIterable {
    case major, minor, patch, preRelease
  }

  public enum PreReleaseStrategy: Equatable, Sendable {
    /// Use output of tag, with branch and commit sha.
    case branchAndCommit

    /// Provide a custom pre-release tag.
    indirect case custom(String, PreReleaseStrategy? = nil)

    /// Use the output of `git describe --tags`
    case tag
  }

  public enum VersionStrategy: Equatable, Sendable {
    case branchAndCommit
    case semVar(SemVarOptions)

    // public typealias SemVarOptions = Configuration.SemVar

    public struct SemVarOptions: Equatable, Sendable {
      let preReleaseStrategy: PreReleaseStrategy?
      let requireExistingFile: Bool
      let requireExistingSemVar: Bool

      public init(
        preReleaseStrategy: PreReleaseStrategy? = nil,
        requireExistingFile: Bool = true,
        requireExistingSemVar: Bool = true
      ) {
        self.preReleaseStrategy = preReleaseStrategy
        self.requireExistingFile = requireExistingFile
        self.requireExistingSemVar = requireExistingSemVar
      }
    }
  }

  public struct SharedOptions: Equatable, Sendable {

    let dryRun: Bool
    let gitDirectory: String?
    let logLevel: Logger.Level
    let preReleaseStrategy: PreReleaseStrategy?
    let target: String
    let versionStrategy: VersionStrategy

    public init(
      dryRun: Bool = false,
      gitDirectory: String? = nil,
      logLevel: Logger.Level = .debug,
      preReleaseStrategy: PreReleaseStrategy? = nil,
      target: String,
      versionStrategy: VersionStrategy = .semVar(.init())
    ) {
      self.dryRun = dryRun
      self.target = target
      self.gitDirectory = gitDirectory
      self.logLevel = logLevel
      self.preReleaseStrategy = preReleaseStrategy
      self.versionStrategy = versionStrategy
    }

    var allowPreReleaseTag: Bool { preReleaseStrategy != nil }
  }

}

extension CliClient: DependencyKey {
  public static let testValue: CliClient = Self()

  public static func live(environment: [String: String]) -> Self {
    .init(
      build: { try await $0.build(environment) },
      bump: { try await $1.bump($0) },
      generate: { try await $0.generate() }
    )
  }

  public static var liveValue: CliClient {
    .live(environment: ProcessInfo.processInfo.environment)
  }
}
