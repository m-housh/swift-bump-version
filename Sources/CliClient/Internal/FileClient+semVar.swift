import Dependencies
import FileClient
import Foundation
import GitClient

@_spi(Internal)
public extension FileClient {
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

  func semvar(
    file: URL,
    gitDirectory: String?
  ) async throws -> (semVar: SemVar?, usesOptionalType: Bool) {
    @Dependency(\.logger) var logger
    let (string, usesOptionalType) = try await getVersionString(fileUrl: file, gitDirectory: gitDirectory)
    let semvar = SemVar(string: string)
    logger.debug("Semvar: \(String(describing: semvar))")
    return (semvar, usesOptionalType)
  }

}
