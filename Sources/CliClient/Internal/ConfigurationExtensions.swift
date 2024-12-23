import ConfigurationClient
import Dependencies
import Foundation
import GitClient

extension Configuration.Target {
  func url(gitDirectory: String?) throws -> URL {
    let filePath: String

    if let path {
      filePath = path
    } else {
      guard let module else {
        throw ConfigurationParsingError.pathOrModuleNotSet
      }

      var path = module.name
      if !path.hasPrefix("Sources") || !path.hasPrefix("./Sources") {
        path = "Sources/\(path)"
      }

      if path.hasPrefix("./") {
        path = String(path.dropFirst(2))
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

extension Configuration.PreReleaseStrategy {

  func preReleaseString(gitDirectory: String?) async throws -> String {
    @Dependency(\.gitClient) var gitClient

    let preReleaseString: String

    if let branch {
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
    guard let preReleaseStrategy = self.preRelease else { return semVar }
    let preRelease = try await preReleaseStrategy.preReleaseString(gitDirectory: gitDirectory)
    return semVar.applyingPreRelease(preRelease)
  }

  func currentVersion(file: URL, gitDirectory: String? = nil) async throws -> CurrentVersionContainer.Version {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.gitClient) var gitClient

    let fileOutput = try? await fileClient.semVar(file: file, gitDirectory: gitDirectory)
    var semVar = fileOutput?.semVar
    let usesOptionalType = fileOutput?.usesOptionalType

    if requireExistingFile {
      guard let semVar else {
        throw CliClientError.fileDoesNotExist(path: file.cleanFilePath)
      }
      return try await .semVar(
        applyingPreRelease(semVar, gitDirectory),
        usesOptionalType: usesOptionalType ?? false
      )
    }

    // Didn't have existing semVar loaded from file, so check for git-tag.

    semVar = try await gitClient.version(.init(
      gitDirectory: gitDirectory,
      style: .tag(exactMatch: false)
    )).semVar

    if requireExistingSemVar {
      guard let semVar else {
        fatalError()
      }
      return try await .semVar(
        applyingPreRelease(semVar, gitDirectory),
        usesOptionalType: usesOptionalType ?? false
      )
    }

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
  case pathOrModuleNotSet
  case versionStrategyError(message: String)
}
