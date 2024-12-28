import Dependencies
import FileClient
import Foundation
import GitClient

@_spi(Internal)
public extension FileClient {

  func loadCurrentVersion(
    url: URL,
    gitDirectory: String?,
    expectsBranch: Bool
  ) async throws -> CurrentVersionContainer.CurrentVersion? {
    @Dependency(\.logger) var logger

    switch expectsBranch {
    case true:
      let (string, usesOptionalType) = try await branch(file: url, gitDirectory: gitDirectory)
      logger.debug("Loaded branch: \(string)")
      return .branch(string, usesOptionalType: usesOptionalType)
    case false:
      let (semvar, usesOptionalType) = try await semvar(file: url, gitDirectory: gitDirectory)
      guard let semvar else { return nil }
      logger.debug("Semvar: \(semvar)")
      return .semvar(semvar, usesOptionalType: usesOptionalType)
    }
  }

  // TODO: Make private.
  func branch(
    file: URL,
    gitDirectory: String?
  ) async throws -> (string: String, usesOptionalType: Bool) {
    let (string, usesOptionalType) = try await getVersionString(fileUrl: file, gitDirectory: gitDirectory)
    return (string, usesOptionalType)
  }

  // TODO: Make private.
  func semvar(
    file: URL,
    gitDirectory: String?
  ) async throws -> (semVar: SemVar?, usesOptionalType: Bool) {
    let (string, usesOptionalType) = try await getVersionString(fileUrl: file, gitDirectory: gitDirectory)
    let semvar = SemVar(string: string)
    return (semvar, usesOptionalType)
  }

  private func getVersionString(
    fileUrl: URL,
    gitDirectory: String?
  ) async throws -> (version: String, usesOptionalType: Bool) {
    @Dependency(\.gitClient) var gitClient
    @Dependency(\.logger) var logger

    let targetUrl = fileUrl

    guard fileExists(targetUrl) else {
      throw CliClientError.fileDoesNotExist(path: fileUrl.cleanFilePath)
    }

    let contents = try await read(targetUrl)
    let versionLine = contents.split(separator: "\n")
      .first { $0.hasPrefix("let VERSION:") }

    guard let versionLine else {
      throw CliClientError.failedToParseVersionFile
    }
    logger.debug("Version line: \(versionLine)")

    let isOptional = versionLine.contains("String?")
    logger.trace("Uses optional: \(isOptional)")

    let versionString = versionLine.split(separator: "let VERSION: \(isOptional ? "String?" : "String") = ").last
    guard let versionString else {
      throw CliClientError.failedToParseVersionFile
    }
    logger.trace("Parsed version string: \(versionString)")
    return (String(versionString), isOptional)
  }

}
