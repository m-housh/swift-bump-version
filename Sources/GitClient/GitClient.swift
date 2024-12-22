import Dependencies
import DependenciesMacros
import FileClient
import Foundation
import ShellClient

public extension DependencyValues {

  /// A ``GitVersionClient`` that can retrieve the current version from a
  /// git directory.
  var gitClient: GitClient {
    get { self[GitClient.self] }
    set { self[GitClient.self] = newValue }
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
public struct GitClient: Sendable {

  /// The closure to run that returns the current version from a given
  /// git directory.
  @available(*, deprecated, message: "Use version.")
  public var currentVersion: @Sendable (String?, Bool) async throws -> String

  /// Get the current version from the `git tag` in the given directory.
  /// If a directory is not passed in, then we will use the current working directory.
  ///
  /// - Parameters:
  ///   - gitDirectory: The directory to run the command in.
  @available(*, deprecated, message: "Use version.")
  public func currentVersion(in gitDirectory: String? = nil, exactMatch: Bool = true) async throws -> String {
    try await currentVersion(gitDirectory, exactMatch)
  }

  public var version: @Sendable (CurrentVersionOption) async throws -> Version

}

public extension GitClient {
  struct CurrentVersionOption: Sendable {
    let gitDirectory: String?
    let style: Style

    public init(
      gitDirectory: String? = nil,
      style: Style
    ) {
      self.gitDirectory = gitDirectory
      self.style = style
    }

    public enum Style: Sendable {
      case tag(exactMatch: Bool = false)
      case branch(commitSha: Bool = true)
    }

  }

  enum Version: Sendable, CustomStringConvertible {
    case branch(String)
    case tag(String)

    public var description: String {
      switch self {
      case let .branch(string): return string
      case let .tag(string): return string
      }
    }
  }
}

extension GitClient: TestDependencyKey {

  /// The ``GitVersionClient`` used in test / debug builds.
  public static let testValue = GitClient()

  /// The ``GitVersionClient`` used in release builds.
  public static var liveValue: GitClient {
    .init(
      currentVersion: { gitDirectory, exactMatch in
        try await GitVersion(workingDirectory: gitDirectory).currentVersion(exactMatch)
      },
      version: { try await $0.run() }
    )
  }

  /// Create a mock git client, that always returns the given value.
  ///
  /// - Parameters:
  ///   - value: The value to return.
  public static func mock(_ value: Version) -> Self {
    .init(
      currentVersion: { _, _ in value.description },
      version: { _ in value }
    )
  }
}

// MARK: - Private

private extension GitClient.CurrentVersionOption {

  func run() async throws -> GitClient.Version {
    switch style {
    case let .tag(exactMatch: exactMatch):
      return try await .tag(runCommand(.describeTag(exactMatch: exactMatch)))
    case let .branch(commitSha: withCommit):
      async let branch = try await runCommand(.branch)

      if withCommit {
        let commit = try await runCommand(.commit)
        return try await .branch("\(branch)-\(commit)")
      }
      return try await .branch(branch)
    }
  }

  func runCommand(_ versionArgs: VersionArgs) async throws -> String {
    @Dependency(\.asyncShellClient) var shell
    @Dependency(\.fileClient) var fileClient

    var gitDirectory: String! = self.gitDirectory
    if gitDirectory == nil {
      gitDirectory = try await fileClient.currentDirectory()
    }

    return try await shell.background(
      .init(
        shell: .env,
        environment: ProcessInfo.processInfo.environment,
        in: gitDirectory,
        versionArgs().map(\.rawValue)
      ),
      trimmingCharactersIn: .whitespacesAndNewlines
    )
  }

  enum VersionArgs {
    case branch
    case commit
    case describeTag(exactMatch: Bool)

    func callAsFunction() -> [Args] {
      switch self {
      case .branch:
        return [.git, .symbolicRef, .quiet, .short, .head]
      case .commit:
        return [.git, .revParse, .short, .head]
      case let .describeTag(exactMatch):
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

public extension GitClient.Version {
  static var mocks: [Self] {
    [
      .tag("1.0.0"),
      .tag("1.0.0-4-g59bc977"),
      .branch("dev-g59bc977")
    ]
  }
}
