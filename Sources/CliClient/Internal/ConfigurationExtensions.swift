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
      throw ConfigurationParsingError.versionStrategyNotFound
    }
    return try await strategy.currentVersion(
      targetUrl: targetUrl,
      gitDirectory: gitDirectory
    )
  }
}

private extension Configuration.SemVar.Strategy {

  func getSemvar(gitDirectory: String? = nil) async throws -> SemVar {
    @Dependency(\.asyncShellClient) var asyncShellClient
    @Dependency(\.gitClient) var gitClient
    @Dependency(\.logger) var logger

    let semvar: SemVar?

    switch self {
    case let .command(arguments: arguments):
      logger.trace("Using custom command strategy with: \(arguments)")
      semvar = try await SemVar(string: asyncShellClient.background(.init(arguments)))
    case let .gitTag(exactMatch: exactMatch):
      logger.trace("Using gitTag strategy.")
      semvar = try await gitClient.version(.init(
        gitDirectory: gitDirectory,
        style: .tag(exactMatch: exactMatch ?? false)
      )).semVar
    }

    guard let semvar else {
      throw CliClientError.semVarNotFound
    }

    return semvar
  }
}

@_spi(Internal)
public extension Configuration.SemVar {

  // TODO: Need to handle custom command semvar strategy.

  func currentVersion(file: URL, gitDirectory: String? = nil) async throws -> CurrentVersionContainer.Version {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.gitClient) var gitClient
    @Dependency(\.logger) var logger

    let fileOutput = try? await fileClient.semvar(file: file, gitDirectory: gitDirectory)
    var semVar = fileOutput?.semVar

    logger.trace("file output semvar: \(String(describing: semVar))")

    let usesOptionalType = fileOutput?.usesOptionalType

    // We parsed a semvar from the existing file, use it.
    if semVar != nil {
      let semvarWithPreRelease = try await applyingPreRelease(semVar!, gitDirectory)

      return .semvar(
        semvarWithPreRelease,
        usesOptionalType: usesOptionalType ?? false,
        hasChanges: semvarWithPreRelease != semVar
      )
    }

    if requireExistingFile == true {
      logger.debug("Failed to parse existing file, and caller requires it.")
      throw CliClientError.fileDoesNotExist(path: file.cleanFilePath)
    }

    logger.trace("Does not require existing file, checking git-tag.")

    // TODO: Is this what we want to do here?  Seems that the strategy should be set by the client / configuration.

    // Didn't have existing semVar loaded from file, so check for git-tag.
    semVar = try await gitClient.version(.init(
      gitDirectory: gitDirectory,
      style: .tag(exactMatch: false)
    )).semVar

    if semVar != nil {
      let semvarWithPreRelease = try await applyingPreRelease(semVar!, gitDirectory)
      return .semvar(
        semvarWithPreRelease,
        usesOptionalType: usesOptionalType ?? false,
        hasChanges: semvarWithPreRelease != semVar
      )
    }

    if requireExistingSemVar == true {
      logger.trace("Caller requires existing semvar and it was not found in file or git-tag.")
      throw CliClientError.semVarNotFound
    }

    // Semvar doesn't exist, so create a new one.
    logger.trace("Generating new semvar.")
    return try await .semvar(
      applyingPreRelease(.init(), gitDirectory),
      usesOptionalType: usesOptionalType ?? false,
      hasChanges: true
    )
  }
}

private extension Configuration.VersionStrategy {

  // TODO: This should just load the `nextVersion`, and should probably live on CurrentVersionContainer.

  // FIX: Fix what's passed to current verions here.
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
        currentVersion: nil,
        version: semvar.currentVersion(file: targetUrl, gitDirectory: gitDirectory)
      )
    }
    return try await .init(
      targetUrl: targetUrl,
      currentVersion: nil,
      version: .string(
        gitClient.version(includeCommitSha: branch.includeCommitSha, gitDirectory: gitDirectory)
      )
    )
  }
}

private extension Configuration.Target {
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

private extension GitClient {
  func version(includeCommitSha: Bool, gitDirectory: String?) async throws -> String {
    @Dependency(\.gitClient) var gitClient

    return try await gitClient.version(.init(
      gitDirectory: gitDirectory,
      style: .branch(commitSha: includeCommitSha)
    )).description
  }
}

private extension Configuration.PreRelease {

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
    case let .command(arguments: arguments, allowPrefix: allowPrefix):
      logger.trace("Command pre-release strategy, arguments: \(arguments).")
      preReleaseString = try await asyncShellClient.background(.init(arguments))
      allowsPrefix = allowPrefix ?? false
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

    if let prefix, allowsPrefix {
      preReleaseString = "\(prefix)-\(preReleaseString)"
    }

    guard suffix else { return .semvar(preReleaseString) }
    return .suffix(preReleaseString)
  }

  enum PreReleaseString: Sendable {
    case suffix(String)
    case semvar(String)
  }
}

private extension Configuration.SemVar {

  func applyingPreRelease(_ semvar: SemVar, _ gitDirectory: String?) async throws -> SemVar {
    @Dependency(\.logger) var logger
    logger.trace("Start apply pre-release to: \(semvar)")

    guard let preReleaseStrategy = self.preRelease,
          let preRelease = try await preReleaseStrategy.preReleaseString(gitDirectory: gitDirectory)
    else {
      logger.trace("No pre-release strategy, returning original semvar.")
      return semvar
    }

    logger.trace("Pre-release string: \(preRelease)")

    switch preRelease {
    case let .suffix(string):
      return semvar.applyingPreRelease(string)
    case let .semvar(string):
      guard let semvar = SemVar(string: string) else {
        throw CliClientError.preReleaseParsingError(string)
      }
      if let prefix = self.preRelease?.prefix {
        var prefixString = prefix
        if let preReleaseString = semvar.preRelease {
          prefixString = "\(prefix)-\(preReleaseString)"
        }
        return semvar.applyingPreRelease(prefixString)
      }
      return semvar
    }
  }
}

enum ConfigurationParsingError: Error {
  case targetNotFound
  case pathOrModuleNotSet
  case versionStrategyError(message: String)
  case versionStrategyNotFound
}
