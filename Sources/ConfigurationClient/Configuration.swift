import Foundation

public struct Configuration: Codable, Sendable {
  public let target: Target?
  public let strategy: VersionStrategy?

  public init(
    target: Target? = nil,
    strategy: VersionStrategy? = .semvar()
  ) {
    self.target = target
    self.strategy = strategy
  }
}

public extension Configuration {

  enum VersionStrategy: Codable, Equatable, Sendable {
    case branch(Branch = .init())
    case semvar(SemVar = .init())

    public struct Branch: Codable, Equatable, Sendable {
      let includeCommitSha: Bool

      public init(includeCommitSha: Bool = true) {
        self.includeCommitSha = includeCommitSha
      }
    }

    public enum PreReleaseStrategy: Codable, Equatable, Sendable {
      /// Use output of tag, with branch and commit sha.
      case branch(Branch = .init())

      /// Provide a custom pre-release tag.
      indirect case custom(String, PreReleaseStrategy? = nil)

      /// Use the output of `git describe --tags`
      case gitTag
    }

    public struct SemVar: Codable, Equatable, Sendable {
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

  enum Target: Codable, Equatable, Sendable {
    case path(String)
    case module(Module)

    public struct Module: Codable, Equatable, Sendable {
      public let name: String
      public let fileName: String

      public init(
        _ name: String,
        fileName: String = "Version.swift"
      ) {
        self.name = name
        self.fileName = fileName
      }
    }
  }
}
