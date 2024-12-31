import ConfigurationClient
import CustomDump
import Dependencies
import FileClient
import Foundation
import LoggingExtensions

enum VersionContainer: Sendable {
  case branch(CurrentVersionContainer<String>)
  case semvar(CurrentVersionContainer<SemVar>)

  static func load(
    projectDirectory: String?,
    strategy: Configuration.VersionStrategy,
    url: URL
  ) async throws -> Self {
    switch strategy {
    case let .branch(includeCommitSha: includeCommitSha):
      return try await .branch(.load(
        branch: .init(includeCommitSha: includeCommitSha),
        projectDirectory: projectDirectory,
        url: url
      ))
    case .semvar:
      return try await .semvar(.load(
        semvar: strategy.semvar!,
        projectDirectory: projectDirectory,
        url: url
      ))
    }
  }
}

// TODO: Add a precedence field for which version to prefer, should also be specified in
//       configuration.
struct CurrentVersionContainer<Version> {
  let targetUrl: URL
  let usesOptionalType: Bool
  let loadedVersion: Version?
  let precedence: Configuration.SemVar.Precedence?
  let strategyVersion: Version?
}

extension CurrentVersionContainer: Equatable where Version: Equatable {

  var hasChanges: Bool {
    switch (loadedVersion, strategyVersion) {
    case (.none, .none):
      return false
    case (.some, .none),
         (.none, .some):
      return true
    case let (.some(loaded), .some(next)):
      return loaded == next
    }
  }
}

extension CurrentVersionContainer: Sendable where Version: Sendable {}

extension CurrentVersionContainer where Version == String {

  static func load(
    branch: Configuration.Branch,
    projectDirectory: String?,
    url: URL
  ) async throws -> Self {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.gitClient) var gitClient

    let loaded = try await fileClient.branch(
      file: url,
      projectDirectory: projectDirectory,
      requireExistingFile: false
    )

    let next = try await gitClient.version(.init(
      gitDirectory: projectDirectory,
      style: .branch(commitSha: branch.includeCommitSha)
    ))

    return .init(
      targetUrl: url,
      usesOptionalType: loaded?.1 ?? true,
      loadedVersion: loaded?.0,
      precedence: nil,
      strategyVersion: next.description
    )
  }

  var versionString: String? {
    loadedVersion ?? strategyVersion
  }
}

extension CurrentVersionContainer where Version == SemVar {

  // TODO: Update to use precedence and not fetch `nextVersion` if we loaded a file version.
  static func load(semvar: Configuration.SemVar, projectDirectory: String?, url: URL) async throws -> Self {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.logger) var logger

    logger.trace("Begin loading semvar from: \(url.cleanFilePath)")

    async let (loaded, usesOptionalType) = try await loadCurrentVersion(
      semvar: semvar,
      projectDirectory: projectDirectory,
      url: url
    )
    async let next = try await loadNextVersion(semvar: semvar, projectDirectory: projectDirectory)

    return try await .init(
      targetUrl: url,
      usesOptionalType: usesOptionalType,
      loadedVersion: loaded,
      precedence: semvar.precedence,
      strategyVersion: next
    )
  }

  static func loadCurrentVersion(
    semvar: Configuration.SemVar,
    projectDirectory: String?,
    url: URL
  ) async throws -> (SemVar?, Bool) {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.logger) var logger

    logger.trace("Begin loading current version from: \(url.cleanFilePath)")

    let loadedOptional = try await fileClient.semvar(
      file: url,
      projectDirectory: projectDirectory,
      requireExistingFile: semvar.requireExistingFile ?? false
    )
    guard let loadedStrong = loadedOptional else {
      if semvar.requireExistingFile ?? false {
        throw CliClientError.semVarNotFound(message: "Required by configuration's 'requireExistingFile' variable.")
      }
      return (nil, true)
    }

    let (loaded, usesOptionalType) = loadedStrong

    logger.dump(loaded) { "Loaded version:\n\($0)" }
    return (loaded, usesOptionalType)
  }

  static func loadNextVersion(semvar: Configuration.SemVar, projectDirectory: String?) async throws -> SemVar? {
    @Dependency(\.logger) var logger
    let next = try await SemVar.nextVersion(
      configuration: semvar,
      projectDirectory: projectDirectory
    )
    logger.dump(next) { "Next version:\n\($0)" }
    return next
  }

  func versionString(withPreRelease: Bool) -> String? {
    let version: SemVar?

    switch precedence ?? .default {
    case .file:
      version = loadedVersion ?? strategyVersion
    case .strategy:
      version = strategyVersion ?? loadedVersion
    }

    return version?.versionString(withPreReleaseTag: withPreRelease)
  }

}
