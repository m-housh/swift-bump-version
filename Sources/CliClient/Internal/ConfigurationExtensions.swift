import ConfigurationClient
import Dependencies
import Foundation
import GitClient

extension Configuration {
  func targetUrl(gitDirectory: String?) throws -> URL {
    guard let target else {
      throw ConfigurationParsingError.targetNotFound
    }
    return try target.url(gitDirectory: gitDirectory)
  }

  func currentVersion(targetUrl: URL, gitDirectory: String?) async throws -> CurrentVersionContainer {
    guard let strategy else {
      throw ConfigurationParsingError.versionNotFound
    }
    return try await strategy.currentVersion(
      targetUrl: targetUrl,
      gitDirectory: gitDirectory
    )
  }
}

extension Configuration.Target {
  func url(gitDirectory: String?) throws -> URL {
    @Dependency(\.logger) var logger

    let filePath: String

    if let path {
      filePath = path
    } else {
      guard let module else {
        throw ConfigurationParsingError.pathOrModuleNotSet
      }

      var path = module.name
      logger.debug("module.name: \(path)")

      if path.hasPrefix("./") {
        path = String(path.dropFirst(2))
      }

      if !path.hasPrefix("Sources") {
        logger.debug("no prefix")
        path = "Sources/\(path)"
      }

      filePath = "\(path)/\(module.fileName)"
    }

    if let gitDirectory {
      return URL(filePath: "\(gitDirectory)/\(filePath)")
    }
    return URL(filePath: filePath)
  }
}

extension GitClient {
  func version(branch: Configuration.Branch, gitDirectory: String?) async throws -> String {
    @Dependency(\.gitClient) var gitClient

    return try await gitClient.version(.init(
      gitDirectory: gitDirectory,
      style: .branch(commitSha: branch.includeCommitSha)
    )).description
  }
}

extension Configuration.PreRelease {

  func preReleaseString(gitDirectory: String?) async throws -> String {
    @Dependency(\.gitClient) var gitClient

    let preReleaseString: String

    if let branch = strategy?.branch {
      preReleaseString = try await gitClient.version(branch: branch, gitDirectory: gitDirectory)
    } else {
      preReleaseString = try await gitClient.version(.init(
        gitDirectory: gitDirectory,
        style: .tag(exactMatch: false)
      )).description
    }

    if let prefix {
      return "\(prefix)-\(preReleaseString)"
    }
    return preReleaseString
  }
}

@_spi(Internal)
public extension Configuration.SemVar {

  private func applyingPreRelease(_ semVar: SemVar, _ gitDirectory: String?) async throws -> SemVar {
    @Dependency(\.logger) var logger
    logger.trace("Start apply pre-release to: \(semVar)")
    guard let preReleaseStrategy = self.preRelease else {
      logger.trace("No pre-release strategy, returning original semvar.")
      return semVar
    }

    let preRelease = try await preReleaseStrategy.preReleaseString(gitDirectory: gitDirectory)
    logger.trace("Pre-release string: \(preRelease)")

    return semVar.applyingPreRelease(preRelease)
  }

  func currentVersion(file: URL, gitDirectory: String? = nil) async throws -> CurrentVersionContainer.Version {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.gitClient) var gitClient
    @Dependency(\.logger) var logger

    let fileOutput = try? await fileClient.semVar(file: file, gitDirectory: gitDirectory)
    var semVar = fileOutput?.semVar

    logger.trace("file output semvar: \(String(describing: semVar))")

    let usesOptionalType = fileOutput?.usesOptionalType

    // We parsed a semvar from the existing file, use it.
    if semVar != nil {
      return try await .semVar(
        applyingPreRelease(semVar!, gitDirectory),
        usesOptionalType: usesOptionalType ?? false
      )
    }

    if requireExistingFile {
      logger.debug("Failed to parse existing file, and caller requires it.")
      throw CliClientError.fileDoesNotExist(path: file.cleanFilePath)
    }

    logger.trace("Does not require existing file, checking git-tag.")

    // Didn't have existing semVar loaded from file, so check for git-tag.
    semVar = try await gitClient.version(.init(
      gitDirectory: gitDirectory,
      style: .tag(exactMatch: false)
    )).semVar

    if semVar != nil {
      return try await .semVar(
        applyingPreRelease(semVar!, gitDirectory),
        usesOptionalType: usesOptionalType ?? false
      )
    }

    if requireExistingSemVar {
      logger.trace("Caller requires existing semvar and it was not found in file or git-tag.")
      throw CliClientError.semVarNotFound
    }

    // Semvar doesn't exist, so create a new one.
    logger.trace("Generating new semvar.")
    return try await .semVar(
      applyingPreRelease(.init(), gitDirectory),
      usesOptionalType: usesOptionalType ?? false
    )
  }
}

extension Configuration.VersionStrategy {

  func currentVersion(targetUrl: URL, gitDirectory: String?) async throws -> CurrentVersionContainer {
    @Dependency(\.gitClient) var gitClient

    guard let branch else {
      guard let semvar else {
        throw ConfigurationParsingError.versionStrategyError(
          message: "Neither branch nor semvar set on configuration."
        )
      }
      return try await .init(
        targetUrl: targetUrl,
        version: semvar.currentVersion(file: targetUrl, gitDirectory: gitDirectory)
      )
    }
    return try await .init(
      targetUrl: targetUrl,
      version: .string(
        gitClient.version(branch: branch, gitDirectory: gitDirectory)
      )
    )
  }
}

enum ConfigurationParsingError: Error {
  case targetNotFound
  case pathOrModuleNotSet
  case versionStrategyError(message: String)
  case versionNotFound
}
