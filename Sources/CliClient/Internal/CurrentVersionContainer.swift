import ConfigurationClient
import CustomDump
import Dependencies
import FileClient
import Foundation

// TODO: Add optional property for currentVersion (loaded version from file)
//       and rename version to nextVersion.

/// An internal type that holds onto the loaded version from a file (if found),
/// the computed next version, and the target file url.
///
@_spi(Internal)
public struct CurrentVersionContainer: Sendable {

  let targetUrl: URL
  let currentVersion: CurrentVersion?
  let version: Version

  // TODO: Derive from current version.
  var usesOptionalType: Bool {
    switch version {
    case .string: return false
    case let .semvar(_, usesOptionalType, _): return usesOptionalType
    }
  }

  var hasChanges: Bool {
    guard let currentVersion else { return false }
    switch (currentVersion, version) {
    case let (.branch(currentString, _), .string(nextString)):
      return currentString == nextString
    case let (.semvar(currentSemvar, _), .semvar(nextSemvar, _, _)):
      return currentSemvar == nextSemvar
    // TODO: What to do with mis-matched values.
    case (.branch, .semvar),
         (.semvar, .string):
      return true
    }
  }

  public enum CurrentVersion: Sendable {
    case branch(String, usesOptionalType: Bool)
    case semvar(SemVar, usesOptionalType: Bool)
  }

  public enum Version: Sendable {
    // TODO: Call this branch for consistency.
    case string(String)
    // TODO: Remove has changes when currentVersion/nextVersion is implemented.
    case semvar(SemVar, usesOptionalType: Bool = true, hasChanges: Bool)

    func string(allowPreReleaseTag: Bool) throws -> String {
      switch self {
      case let .string(string):
        return string
      case let .semvar(semvar, usesOptionalType: _, hasChanges: _):
        return semvar.versionString(withPreReleaseTag: allowPreReleaseTag)
      }
    }
  }
}

extension CurrentVersionContainer {

  static func load(
    configuration: Configuration,
    sharedOptions: CliClient.SharedOptions
  ) async throws -> Self {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.logger) var logger

    let targetUrl = try configuration.targetUrl(gitDirectory: sharedOptions.projectDirectory)
    logger.trace("Begin loading current version from: \(targetUrl.cleanFilePath)")

    let currentVersion = try await fileClient.loadCurrentVersion(
      url: targetUrl,
      gitDirectory: sharedOptions.projectDirectory,
      expectsBranch: configuration.strategy?.branch != nil
    )
    var currentVersionString = ""
    customDump(currentVersion, to: &currentVersionString)
    logger.trace("Loaded current version:\n\(currentVersionString)")

    if configuration.strategy?.semvar?.requireExistingFile == true {
      guard currentVersion != nil else {
        // TODO: Better error.
        throw CliClientError.semVarNotFound
      }
    }

    // Check that there's a valid strategy to get the next version.
    guard let strategy = configuration.strategy else {
      // TODO: Return without a next version here when nextVersion is optional.
      fatalError()
    }

    // TODO: make optional?
    let next = try await strategy.loadNextVersion(gitDirectory: sharedOptions.projectDirectory)

    fatalError()
  }
}
