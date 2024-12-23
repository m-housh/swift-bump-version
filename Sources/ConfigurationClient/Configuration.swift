import Foundation
import TOMLKit

/// Represents configuration that can be set via a file, generally in the root of the
/// project directory.
///
///
public struct Configuration: Codable, Equatable, Sendable {

  /// The target for the version.
  public let target: Target?

  /// The strategy used for deriving the version.
  public let strategy: VersionStrategy?

  public init(
    target: Target? = nil,
    strategy: VersionStrategy? = .init(semvar: .init())
  ) {
    self.target = target
    self.strategy = strategy
  }

  public static var mock: Self {
    .init(
      target: .init(module: .init("cli-version")),
      strategy: .init()
    )
  }

  public static var customPreRelease: Self {
    .init(
      target: .init(module: .init("cli-version")),
      strategy: .init(semvar: .init(
        preRelease: .customBranchPrefix("rc")
      ))
    )
  }
}

public extension Configuration {

  /// Represents a branch version or pre-release strategy.
  ///
  /// This derives the version from the branch name and short version
  /// of the commit sha if configured.
  struct Branch: Codable, Equatable, Sendable {

    /// Include the commit sha in the output for this strategy.
    let includeCommitSha: Bool

    /// Create a new branch strategy.
    ///
    /// - Parameters:
    ///   - includeCommitSha: Whether to include the commit sha.
    public init(includeCommitSha: Bool = true) {
      self.includeCommitSha = includeCommitSha
    }
  }

  /// Represents version strategy for pre-release.
  ///
  /// This appends a suffix to the version that get's generated from the version strategy.
  /// For example: `1.0.0-rc-1`
  ///
  struct PreReleaseStrategy: Codable, Equatable, Sendable {

    /// Use branch and commit sha as pre-release suffix.
    public let branch: Branch?

    /// Use a custom prefix string.
    public let prefix: String?

    /// An identifier for the type of pre-release.
    public let style: StyleId

    /// Whether we use `git describe --tags` for part of the suffix, this is only used
    /// if we have a custom style.
    public let usesGitTag: Bool

    init(
      style: StyleId,
      branch: Branch? = nil,
      prefix: String? = nil,
      usesGitTag: Bool = false
    ) {
      self.branch = branch
      self.prefix = prefix
      self.style = style
      self.usesGitTag = usesGitTag
    }

    /// Represents a pre-release strategy that is derived from calling
    /// `git describe --tags`.
    public static let gitTag = Self(style: StyleId.gitTag)

    /// Represents a pre-release strategy that is derived from the branch and commit sha.
    public static func branch(_ branch: Branch = .init()) -> Self {
      .init(style: .branch, branch: branch)
    }

    /// Represents a custom strategy that uses the given value, not deriving any other
    /// data.
    public static func custom(_ prefix: String) -> Self {
      .init(style: .custom, prefix: prefix)
    }

    /// Represents a custom strategy that uses a prefix along with the branch and
    /// commit sha.
    public static func customBranchPrefix(
      _ prefix: String,
      branch: Branch = .init()
    ) -> Self {
      .init(style: .custom, branch: branch, prefix: prefix)
    }

    /// Represents a custom strategy that uses a prefix along with the output from
    /// calling `git describe --tags`.
    public static func customGitTagPrefix(_ prefix: String) -> Self {
      .init(style: StyleId.custom, prefix: prefix, usesGitTag: true)
    }

    public enum StyleId: String, Codable, Sendable {
      case branch
      case custom
      case gitTag
    }
  }

  /// Represents a semvar version strategy.
  ///
  /// ## Example: 1.0.0
  ///
  struct SemVar: Codable, Equatable, Sendable {

    /// Optional pre-releas suffix strategy.
    public let preRelease: PreReleaseStrategy?

    /// Fail if an existing version file does not exist in the target.
    public let requireExistingFile: Bool

    /// Fail if an existing semvar is not parsed from the file or version generation strategy.
    public let requireExistingSemVar: Bool

    public init(
      preRelease: PreReleaseStrategy? = nil,
      requireExistingFile: Bool = true,
      requireExistingSemVar: Bool = true
    ) {
      self.preRelease = preRelease
      self.requireExistingFile = requireExistingFile
      self.requireExistingSemVar = requireExistingSemVar
    }

  }

  /// Represents the target where we will bump the version in.
  ///
  /// This can either be a path to a version file or a module used to
  /// locate the version file.
  struct Target: Codable, Equatable, Sendable {

    /// The path to a version file.
    public let path: String?

    /// A module to find the version file in.
    public let module: Module?

    /// Create a target for the given path.
    ///
    /// - Parameters:
    ///   - path: The path to the version file.
    public init(path: String) {
      self.path = path
      self.module = nil
    }

    /// Create a target for the given module.
    ///
    /// - Parameters:
    ///   - module: The module for the version file.
    public init(module: Module) {
      self.path = nil
      self.module = module
    }

    /// Represents a module target for a version file.
    ///
    public struct Module: Codable, Equatable, Sendable {

      /// The module directory name.
      public let name: String

      /// The version file name located in the module directory.
      public let fileName: String

      /// Create a new module target.
      ///
      /// - Parameters:
      ///   - name: The module directory name.
      ///   - fileName: The file name located in the module directory.
      public init(
        _ name: String,
        fileName: String = "Version.swift"
      ) {
        self.name = name
        self.fileName = fileName
      }
    }
  }

  /// Strategy used to generate a version.
  ///
  /// Typically a `SemVar` strategy or `Branch`.
  ///
  ///
  struct VersionStrategy: Codable, Equatable, Sendable {

    /// Set if we're using the branch and commit sha to derive the version.
    let branch: Branch?

    /// Set if we're using semvar to derive the version.
    let semvar: SemVar?

    /// Create a new version strategy that uses branch and commit sha to derive the version.
    ///
    /// - Parameters:
    ///   - branch: The branch strategy options.
    public init(branch: Branch) {
      self.branch = branch
      self.semvar = nil
    }

    /// Create a new version strategy that uses semvar to derive the version.
    ///
    /// - Parameters:
    ///   - semvar: The semvar strategy options.
    public init(semvar: SemVar = .init()) {
      self.branch = nil
      self.semvar = semvar
    }

  }
}
