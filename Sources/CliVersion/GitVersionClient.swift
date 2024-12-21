import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Dependencies
import DependenciesMacros
import ShellClient

// TODO: This can be an internal dependency.
public extension DependencyValues {

  /// A ``GitVersionClient`` that can retrieve the current version from a
  /// git directory.
  var gitVersionClient: GitVersionClient {
    get { self[GitVersionClient.self] }
    set { self[GitVersionClient.self] = newValue }
  }
}

/// A client that can retrieve the current version from a git directory.
/// It will use the current `tag`, or if the current git tree does not
/// point to a commit that is tagged, it will use the `branch git-sha` as
/// the version.
///
/// This is often not used directly, instead it is used with one of the plugins
/// that is supplied with this library.  The use case is to set the version of a command line
/// tool based on the current git tag.
///
@DependencyClient
public struct GitVersionClient: Sendable {

  /// The closure to run that returns the current version from a given
  /// git directory.
  public var currentVersion: @Sendable (String?, Bool) async throws -> String

  /// Get the current version from the `git tag` in the given directory.
  /// If a directory is not passed in, then we will use the current working directory.
  ///
  /// - Parameters:
  ///   - gitDirectory: The directory to run the command in.
  public func currentVersion(in gitDirectory: String? = nil, exactMatch: Bool = true) async throws -> String {
    try await currentVersion(gitDirectory, exactMatch)
  }
}

extension GitVersionClient: TestDependencyKey {

  /// The ``GitVersionClient`` used in test / debug builds.
  public static let testValue = GitVersionClient()

  /// The ``GitVersionClient`` used in release builds.
  public static var liveValue: GitVersionClient {
    .init(currentVersion: { gitDirectory, exactMatch in
      try await GitVersion(workingDirectory: gitDirectory).currentVersion(exactMatch)
    })
  }
}

// MARK: - Private

private struct GitVersion {
  @Dependency(\.logger) var logger: Logger
  @Dependency(\.asyncShellClient) var shell

  let workingDirectory: String?

  func currentVersion(_ exactMatch: Bool) async throws -> String {
    logger.debug("\("Fetching current version".bold)")
    do {
      logger.debug("Checking for tag.")
      return try await run(command: command(for: .describe(exactMatch: exactMatch)))
    } catch {
      logger.debug("\("No tag found, deferring to branch & git sha".red)")
      let branch = try await run(command: command(for: .branch))
      let commit = try await run(command: command(for: .commit))
      return "\(branch) \(commit)"
    }
  }

  func command(for argument: VersionArgs) -> ShellCommand {
    .init(
      shell: .env,
      environment: nil,
      in: workingDirectory ?? FileManager.default.currentDirectoryPath,
      argument.arguments.map(\.rawValue)
    )
  }

  func run(command: ShellCommand) async throws -> String {
    try await shell.background(command, trimmingCharactersIn: .whitespacesAndNewlines)
  }

  enum VersionArgs {
    case branch
    case commit
    case describe(exactMatch: Bool)

    var arguments: [Args] {
      switch self {
      case .branch:
        return [.git, .symbolicRef, .quiet, .short, .head]
      case .commit:
        return [.git, .revParse, .short, .head]
      case let .describe(exactMatch):
        var args = [Args.git, .describe, .tags]
        if exactMatch {
          args.append(.exactMatch)
        }
        return args
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
