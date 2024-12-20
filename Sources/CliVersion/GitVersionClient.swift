import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import ShellClient
import XCTestDynamicOverlay

/// A client that can retrieve the current version from a git directory.
/// It will use the current `tag`, or if the current git tree does not
/// point to a commit that is tagged, it will use the `branch git-sha` as
/// the version.
///
/// This is often not used directly, instead it is used with one of the plugins
/// that is supplied with this library.  The use case is to set the version of a command line
/// tool based on the current git tag.
///
public struct GitVersionClient {

  /// The closure to run that returns the current version from a given
  /// git directory.
  private var currentVersion: (String?) throws -> String

  /// Create a new ``GitVersionClient`` instance.
  ///
  /// This is normally not interacted with directly, instead access the client through the dependency system.
  /// ```swift
  /// @Dependency(\.gitVersionClient)
  /// ```
  ///
  /// - Parameters:
  ///   - currentVersion: The closure that returns the current version.
  ///
  public init(currentVersion: @escaping (String?) throws -> String) {
    self.currentVersion = currentVersion
  }

  /// Get the current version from the `git tag` in the given directory.
  /// If a directory is not passed in, then we will use the current working directory.
  ///
  /// - Parameters:
  ///   - gitDirectory: The directory to run the command in.
  public func currentVersion(in gitDirectory: String? = nil) throws -> String {
    try currentVersion(gitDirectory)
  }

  /// Override the `currentVersion` command and return the passed in version string.
  ///
  /// This is useful for testing purposes.
  ///
  /// - Parameters:
  ///   - version: The version string to return when `currentVersion` is called.
  public mutating func override(with version: String) {
    currentVersion = { _ in version }
  }
}

extension GitVersionClient: TestDependencyKey {

  /// The ``GitVersionClient`` used in test / debug builds.
  public static let testValue = GitVersionClient(
    currentVersion: unimplemented("\(Self.self).currentVersion", placeholder: "")
  )

  /// The ``GitVersionClient`` used in release builds.
  public static var liveValue: GitVersionClient {
    .init(currentVersion: { gitDirectory in
      try GitVersion(workingDirectory: gitDirectory).currentVersion()
    })
  }
}

public extension DependencyValues {

  /// A ``GitVersionClient`` that can retrieve the current version from a
  /// git directory.
  var gitVersionClient: GitVersionClient {
    get { self[GitVersionClient.self] }
    set { self[GitVersionClient.self] = newValue }
  }
}

public extension ShellCommand {
  static func gitCurrentSha(gitDirectory: String? = nil) -> Self {
    GitVersion(workingDirectory: gitDirectory).command(for: .commit)
  }

  static func gitCurrentBranch(gitDirectory: String? = nil) -> Self {
    GitVersion(workingDirectory: gitDirectory).command(for: .branch)
  }

  static func gitCurrentTag(gitDirectory: String? = nil) -> Self {
    GitVersion(workingDirectory: gitDirectory).command(for: .describe)
  }
}

// MARK: - Private

private struct GitVersion {
  @Dependency(\.logger) var logger: Logger
  @Dependency(\.shellClient) var shell: ShellClient

  let workingDirectory: String?

  func currentVersion() throws -> String {
    logger.debug("\("Fetching current version".bold)")
    do {
      logger.debug("Checking for tag.")
      return try run(command: command(for: .describe))
    } catch {
      logger.debug("\("No tag found, deferring to branch & git sha".red)")
      let branch = try run(command: command(for: .branch))
      let commit = try run(command: command(for: .commit))
      return "\(branch) \(commit)"
    }
  }

  func command(for argument: VersionArgs) -> ShellCommand {
    .init(
      shell: .env,
      environment: nil,
      in: workingDirectory ?? FileManager.default.currentDirectoryPath,
      argument.arguments
    )
  }
}

private extension GitVersion {
  func run(command: ShellCommand) throws -> String {
    try shell.background(command, trimmingCharactersIn: .whitespacesAndNewlines)
  }

  enum VersionArgs {
    case branch
    case commit
    case describe

    var arguments: [Args] {
      switch self {
      case .branch:
        return [.git, .symbolicRef, .quiet, .short, .head]
      case .commit:
        return [.git, .revParse, .short, .head]
      case .describe:
        return [.git, .describe, .tags, .exactMatch]
      }
    }

    enum Args: String, CustomStringConvertible {
      case git
      case describe
      case tags = "--tags"
      case exactMatch = "--exact-match"
      case quiet = "--quiet"
      case symbolicRef = "symbolic-ref"
      case revParse = "rev-parse"
      case short = "--short"
      case head = "HEAD"
    }

  }
}

extension RawRepresentable where RawValue == String, Self: CustomStringConvertible {
  var description: String { rawValue }
}
