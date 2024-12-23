import Dependencies
import FileClient
import struct Foundation.URL
import GitClient

@_spi(Internal)
public extension CliClient.PreReleaseStrategy {

  func preReleaseString(gitDirectory: String?) async throws -> String {
    @Dependency(\.gitClient) var gitClient
    switch self {
    case let .custom(string, child):
      guard let child else { return string }
      return try await "\(string)-\(child.preReleaseString(gitDirectory: gitDirectory))"
    case .tag:
      return try await gitClient.version(.init(
        gitDirectory: gitDirectory,
        style: .tag(exactMatch: false)
      )).description
    case .branchAndCommit:
      return try await gitClient.version(.init(
        gitDirectory: gitDirectory,
        style: .branch(commitSha: true)
      )).description
    }
  }
}

@_spi(Internal)
public extension CliClient.VersionStrategy.SemVarOptions {

  private func applyingPreRelease(_ semVar: SemVar, _ gitDirectory: String?) async throws -> SemVar {
    guard let preReleaseStrategy else { return semVar }
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

@_spi(Internal)
public extension CliClient.VersionStrategy {

  func currentVersion(file: URL, gitDirectory: String?) async throws -> CurrentVersionContainer {
    @Dependency(\.gitClient) var gitClient

    switch self {
    case .branchAndCommit:
      return try await .init(
        targetUrl: file,
        version: .string(
          gitClient.version(.init(
            gitDirectory: gitDirectory,
            style: .branch(commitSha: true)
          )).description
        )
      )
    case let .semVar(options):
      return try await .init(
        targetUrl: file,
        version: options.currentVersion(file: file, gitDirectory: gitDirectory)
      )
    }
  }
}
