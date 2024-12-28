import ConfigurationClient
import CustomDump
import Dependencies
import FileClient
import Foundation
import LoggingExtensions

enum VersionContainer: Sendable {
  case branch(CurrentVersionContainer2<String>)
  case semvar(CurrentVersionContainer2<SemVar>)

  static func load(
    projectDirectory: String?,
    strategy: Configuration.VersionStrategy,
    url: URL
  ) async throws -> Self {
    switch strategy {
    case let .branch(includeCommitSha: includeCommitSha):
      return try await .branch(.load(
        branch: .init(includeCommitSha: includeCommitSha),
        gitDirectory: projectDirectory,
        url: url
      ))
    case .semvar:
      return try await .semvar(.load(
        semvar: strategy.semvar!,
        gitDirectory: projectDirectory,
        url: url
      ))
    }
  }
}

struct CurrentVersionContainer2<Version> {
  let targetUrl: URL
  let usesOptionalType: Bool
  let loadedVersion: Version?
  // TODO: Rename to strategyVersion
  let nextVersion: Version?
}

extension CurrentVersionContainer2: Equatable where Version: Equatable {

  var hasChanges: Bool {
    switch (loadedVersion, nextVersion) {
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

extension CurrentVersionContainer2: Sendable where Version: Sendable {}

extension CurrentVersionContainer2 where Version == String {

  static func load(
    branch: Configuration.Branch,
    gitDirectory: String?,
    url: URL
  ) async throws -> Self {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.gitClient) var gitClient

    let loaded = try await fileClient.branch(
      file: url,
      gitDirectory: gitDirectory,
      requireExistingFile: false
    )

    let next = try await gitClient.version(.init(
      gitDirectory: gitDirectory,
      style: .branch(commitSha: branch.includeCommitSha)
    ))

    return .init(
      targetUrl: url,
      usesOptionalType: loaded?.1 ?? true,
      loadedVersion: loaded?.0,
      nextVersion: next.description
    )
  }

  var versionString: String? {
    loadedVersion ?? nextVersion
  }
}

extension CurrentVersionContainer2 where Version == SemVar {

  static func load(semvar: Configuration.SemVar, gitDirectory: String?, url: URL) async throws -> Self {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.logger) var logger

    logger.trace("Begin loading semvar from: \(url.cleanFilePath)")

    async let (loaded, usesOptionalType) = try await loadCurrentVersion(
      semvar: semvar,
      gitDirectory: gitDirectory,
      url: url
    )
    async let next = try await loadNextVersion(semvar: semvar, projectDirectory: gitDirectory)

    return try await .init(
      targetUrl: url,
      usesOptionalType: usesOptionalType,
      loadedVersion: loaded,
      nextVersion: next
    )
  }

  static func loadCurrentVersion(
    semvar: Configuration.SemVar,
    gitDirectory: String?,
    url: URL
  ) async throws -> (SemVar?, Bool) {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.logger) var logger

    logger.trace("Begin loading current version from: \(url.cleanFilePath)")

    let loadedOptional = try await fileClient.semvar(
      file: url,
      gitDirectory: gitDirectory,
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
    nextVersion?.versionString(withPreReleaseTag: withPreRelease)
      ?? loadedVersion?.versionString(withPreReleaseTag: withPreRelease)
  }

  func withUpdateNextVersion(_ next: SemVar) -> Self {
    .init(targetUrl: targetUrl, usesOptionalType: usesOptionalType, loadedVersion: loadedVersion, nextVersion: next)
  }
}
