import Dependencies
import FileClient
import Foundation
import GitClient

@_spi(Internal)
public extension FileClient {
  func branch(
    file: URL,
    gitDirectory: String?,
    requireExistingFile: Bool
  ) async throws -> (string: String, usesOptionalType: Bool)? {
    let loaded = try? await getVersionString(fileUrl: file, gitDirectory: gitDirectory)
    guard let loaded else {
      if requireExistingFile {
        throw CliClientError.fileDoesNotExist(path: file.cleanFilePath)
      }
      return nil
    }
    return (loaded.0, loaded.1)
  }

  func semvar(
    file: URL,
    gitDirectory: String?,
    requireExistingFile: Bool
  ) async throws -> (semVar: SemVar?, usesOptionalType: Bool)? {
    let loaded = try? await getVersionString(fileUrl: file, gitDirectory: gitDirectory)
    guard let loaded else {
      if requireExistingFile {
        throw CliClientError.fileDoesNotExist(path: file.cleanFilePath)
      }
      return nil
    }
    let semvar = SemVar(string: loaded.0)
    return (semvar, loaded.1)
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
