import ConfigurationClient
import Foundation
import GitClient
import LoggingExtensions
import ShellClient

extension SemVar {
  static func nextVersion(
    configuration: Configuration.SemVar,
    projectDirectory: String?
  ) async throws -> Self? {
    @Dependency(\.asyncShellClient) var asyncShellClient
    @Dependency(\.gitClient) var gitClient
    @Dependency(\.logger) var logger

    guard let strategy = configuration.strategy else { return nil }

    let semvarString: String

    switch strategy {
    case let .gitTag(exactMatch: exactMatch):
      logger.trace("Loading semvar gitTag strategy...")

      semvarString = try await gitClient.version(.init(
        gitDirectory: projectDirectory,
        style: .tag(exactMatch: exactMatch ?? false)
      )).description

    case let .command(arguments: arguments):
      logger.trace("Loading semvar custom command strategy: \(arguments)")
      semvarString = try await asyncShellClient.background(.init(arguments))
    }

    var preReleaseString: String?
    if let preRelease = configuration.preRelease,
       configuration.allowPreRelease ?? true
    {
      preReleaseString = try await preRelease.get(projectDirectory: projectDirectory)
    }

    let semvar = SemVar(string: semvarString)

    if let preReleaseString {
      return semvar?.applyingPreRelease(preReleaseString)
    }

    return semvar
  }
}

private extension Configuration.PreRelease {

  func get(projectDirectory: String?) async throws -> String? {
    @Dependency(\.asyncShellClient) var asyncShellClient
    @Dependency(\.gitClient) var gitClient
    @Dependency(\.logger) var logger

    var allowsPrefix = true
    var preReleaseString: String

    guard let strategy else { return nil }
    switch strategy {
    case let .branch(includeCommitSha: includeCommitSha):
      logger.trace("Loading pre-relase branch strategy...")
      preReleaseString = try await gitClient.version(.init(
        gitDirectory: projectDirectory,
        style: .branch(commitSha: includeCommitSha)
      )).description

    case .gitTag:
      logger.trace("Loading pre-relase gitTag strategy...")
      preReleaseString = try await gitClient.version(.init(
        gitDirectory: projectDirectory,
        style: .tag(exactMatch: false)
      )).description

    case let .command(arguments: arguments, allowPrefix: allowPrefix):
      logger.trace("Loading pre-relase custom command strategy...")
      allowsPrefix = allowPrefix ?? false
      preReleaseString = try await asyncShellClient.background(.init(arguments))
    }

    if let prefix, allowsPrefix {
      preReleaseString = "\(prefix)-\(preReleaseString)"
    }

    logger.trace("Pre-release string: \(preReleaseString)")
    return preReleaseString
  }
}
