import ConfigurationClient
import Dependencies
import Foundation
import GitClient
import ShellClient

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

      filePath = "\(path)/\(module.fileNameOrDefault)"
    }

    if let gitDirectory {
      return URL(filePath: "\(gitDirectory)/\(filePath)")
    }
    return URL(filePath: filePath)
  }
}

extension GitClient {
  func version(includeCommitSha: Bool, gitDirectory: String?) async throws -> String {
    @Dependency(\.gitClient) var gitClient

    return try await gitClient.version(.init(
      gitDirectory: gitDirectory,
      style: .branch(commitSha: includeCommitSha)
    )).description
  }
}

extension Configuration.PreRelease {

  // FIX: This needs to handle the pre-release type appropriatly.
  func preReleaseString(gitDirectory: String?) async throws -> PreReleaseString? {
    guard let strategy else { return nil }

    @Dependency(\.asyncShellClient) var asyncShellClient
    @Dependency(\.gitClient) var gitClient
    @Dependency(\.logger) var logger

    var preReleaseString: String
    var suffix = true
    var allowsPrefix = true

    switch strategy {
    case let .branch(includeCommitSha: includeCommitSha):
      logger.trace("Branch pre-release strategy, includeCommitSha: \(includeCommitSha).")
      preReleaseString = try await gitClient.version(
        includeCommitSha: includeCommitSha,
        gitDirectory: gitDirectory
      )
    case let .command(arguments: arguments):
      logger.trace("Command pre-release strategy, arguments: \(arguments).")
      // TODO: What to do with allows prefix? Need a configuration setting for commands.
      preReleaseString = try await asyncShellClient.background(.init(arguments))
    case .gitTag:
      logger.trace("Git tag pre-release strategy.")
      logger.trace("This will ignore any set prefix.")
      suffix = false
      allowsPrefix = false
      preReleaseString = try await gitClient.version(.init(
        gitDirectory: gitDirectory,
        style: .tag(exactMatch: false)
      )).description
    }

    if let prefix {
      if allowsPrefix {
        preReleaseString = "\(prefix)-\(preReleaseString)"
      } else {
        logger.warning("Found prefix, but pre-release strategy may not work properly, ignoring prefix.")
      }
    }

    guard suffix else { return .semvar(preReleaseString) }
    return .suffix(preReleaseString)

    // return preReleaseString
  }

  enum PreReleaseString: Sendable {
    case suffix(String)
    case semvar(String)
  }
}

@_spi(Internal)
public extension Configuration.SemVar {

  private func applyingPreRelease(_ semVar: SemVar, _ gitDirectory: String?) async throws -> SemVar {
    @Dependency(\.logger) var logger
    logger.trace("Start apply pre-release to: \(semVar)")

    guard let preReleaseStrategy = self.preRelease,
          let preRelease = try await preReleaseStrategy.preReleaseString(gitDirectory: gitDirectory)
    else {
      logger.trace("No pre-release strategy, returning original semvar.")
      return semVar
    }

    // let preRelease = try await preReleaseStrategy.preReleaseString(gitDirectory: gitDirectory)
    logger.trace("Pre-release string: \(preRelease)")

    switch preRelease {
    case let .suffix(string):
      return semVar.applyingPreRelease(string)
    case let .semvar(string):
      guard let semvar = SemVar(string: string) else {
        throw CliClientError.preReleaseParsingError(string)
      }
      return semvar
    }

    // return semVar.applyingPreRelease(preRelease)
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
        gitClient.version(includeCommitSha: branch.includeCommitSha, gitDirectory: gitDirectory)
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
