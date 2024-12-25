import CustomDump
import Foundation

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
    strategy: VersionStrategy? = .semvar(.init())
  ) {
    self.target = target
    self.strategy = strategy
  }

  public static var `default`: Self { .mock(module: "<my-tool>") }

  public static func mock(module: String = "cli-version") -> Self {
    .init(
      target: .init(module: .init(module)),
      strategy: .semvar(.init(strategy: .gitTag(exactMatch: false)))
    )
  }

  public static var customPreRelease: Self {
    .init(
      target: .init(module: .init("cli-version")),
      strategy: .semvar(.init(
        preRelease: .init(prefix: "rc", strategy: .branch())
      ))
    )
  }
}

public extension Configuration {

  /// Represents a branch version or pre-release strategy.
  ///
  /// This derives the version or pre-release suffix from the branch name and
  /// optionally the short version of the commit sha.
  struct Branch: Codable, Equatable, Sendable {

    /// Include the commit sha in the output for this strategy.
    public let includeCommitSha: Bool

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
  struct PreRelease: Codable, Equatable, Sendable {

    public let prefix: String?
    // TODO: Remove optional.
    public let strategy: Strategy?

    public init(
      prefix: String? = nil,
      strategy: Strategy? = nil
    ) {
      self.prefix = prefix
      self.strategy = strategy
    }

    public enum Strategy: Codable, Equatable, Sendable {
      case branch(includeCommitSha: Bool = true)
      case command(arguments: [String])
      // TODO: Remove.
      case gitTag

      public var branch: Branch? {
        guard case let .branch(includeCommitSha) = self
        else { return nil }
        return .init(includeCommitSha: includeCommitSha)
      }
    }
  }

  /// Represents a semvar version strategy.
  ///
  /// ## Example: 1.0.0
  ///
  struct SemVar: Codable, Equatable, Sendable {

    public let allowPreRelease: Bool?

    /// Optional pre-releas suffix strategy.
    public let preRelease: PreRelease?

    /// Fail if an existing version file does not exist in the target.
    public let requireExistingFile: Bool?

    /// Fail if an existing semvar is not parsed from the file or version generation strategy.
    public let requireExistingSemVar: Bool?

    public let strategy: Strategy?

    public init(
      allowPreRelease: Bool? = true,
      preRelease: PreRelease? = nil,
      requireExistingFile: Bool? = true,
      requireExistingSemVar: Bool? = true,
      strategy: Strategy? = nil
    ) {
      self.allowPreRelease = allowPreRelease
      self.preRelease = preRelease
      self.requireExistingFile = requireExistingFile
      self.requireExistingSemVar = requireExistingSemVar
      self.strategy = strategy
    }

    public enum Strategy: Codable, Equatable, Sendable {
      case command(arguments: [String])
      case gitTag(exactMatch: Bool? = false)
    }

  }

  /// Represents the target where we will bump the version in.
  ///
  /// This can either be a path to a version file or a module used to
  /// locate the version file.
  struct Target: Codable, Equatable, Sendable, CustomDumpReflectable {

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
    public struct Module: Codable, Equatable, Sendable, CustomDumpReflectable {

      /// The module directory name.
      public let name: String

      /// The version file name located in the module directory.
      public let fileName: String?

      /// Create a new module target.
      ///
      /// - Parameters:
      ///   - name: The module directory name.
      ///   - fileName: The file name located in the module directory.
      public init(
        _ name: String,
        fileName: String? = nil
      ) {
        self.name = name
        self.fileName = fileName
      }

      public var fileNameOrDefault: String {
        fileName ?? "Version.swift"
      }

      public var customDumpMirror: Mirror {
        .init(
          self,
          children: [
            "name": name,
            "fileName": fileNameOrDefault
          ],
          displayStyle: .struct
        )
      }

    }

    public var customDumpMirror: Mirror {
      guard let module else {
        guard let path else { return .init(reflecting: self) }
        return .init(
          self,
          children: [
            "path": path
          ],
          displayStyle: .struct
        )
      }
      return .init(
        self,
        children: [
          "module": module
        ],
        displayStyle: .struct
      )
    }
  }

  /// Strategy used to generate a version.
  ///
  /// Typically a `SemVar` strategy or `Branch`.
  ///
  ///
  enum VersionStrategy: Codable, Equatable, Sendable, CustomDumpReflectable {
    case branch(includeCommitSha: Bool = true)

    case semvar(
      allowPreRelease: Bool? = nil,
      preRelease: PreRelease? = nil,
      requireExistingFile: Bool? = nil,
      requireExistingSemVar: Bool? = nil,
      strategy: SemVar.Strategy? = nil
    )

    public var branch: Branch? {
      guard case let .branch(includeCommitSha) = self
      else { return nil }

      return .init(includeCommitSha: includeCommitSha)
    }

    public var semvar: SemVar? {
      guard case let .semvar(allowPreRelease, preRelease, requireExistingFile, requireExistingSemVar, strategy) = self
      else { return nil }
      return .init(
        allowPreRelease: allowPreRelease,
        preRelease: preRelease,
        requireExistingFile: requireExistingFile ?? false,
        requireExistingSemVar: requireExistingSemVar ?? false,
        strategy: strategy
      )
    }

    public static func branch(_ branch: Branch) -> Self {
      .branch(includeCommitSha: branch.includeCommitSha)
    }

    public static func semvar(_ value: SemVar) -> Self {
      .semvar(
        allowPreRelease: value.allowPreRelease,
        preRelease: value.preRelease,
        requireExistingFile: value.requireExistingFile,
        requireExistingSemVar: value.requireExistingSemVar,
        strategy: value.strategy
      )
    }

    public var customDumpMirror: Mirror {
      switch self {
      case .branch:
        return .init(self, children: ["branch": branch!], displayStyle: .struct)
      case .semvar:
        return .init(self, children: ["semvar": semvar!], displayStyle: .struct)
      }
    }
  }

}
