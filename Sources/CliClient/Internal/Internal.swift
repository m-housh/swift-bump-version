import ConfigurationClient
import Dependencies
import FileClient
import Foundation
import GitClient

@_spi(Internal)
public extension CliClient.SharedOptions {

  @discardableResult
  func run(
    _ operation: (CurrentVersionContainer) async throws -> Void
  ) async rethrows -> String {
    try await withDependencies {
      $0.logger.logLevel = logLevel
    } operation: {
      // Load the default configuration, if it exists.
      try await withConfiguration(path: configurationFile) { configuration in
        @Dependency(\.logger) var logger

        // Merge any configuration set from caller into default configuration.
        var configuration = configuration
        configuration = configuration.mergingTarget(target)

        if configuration.strategy?.branch != nil, let branch {
          configuration = configuration.mergingStrategy(.branch(branch))
        } else if let semvar {
          configuration = configuration.mergingStrategy(.semvar(semvar))
        }

        logger.debug("Configuration: \(configuration)")

        // This will fail if the target url is not set properly.
        let targetUrl = try configuration.targetUrl(gitDirectory: gitDirectory)
        logger.debug("Target: \(targetUrl.cleanFilePath)")

        // Perform the operation, which generates the new version and writes it.
        try await operation(
          configuration.currentVersion(
            targetUrl: targetUrl,
            gitDirectory: gitDirectory
          )
        )

        // Return the file path we wrote the version to.
        return targetUrl.cleanFilePath
      }
    }
  }

  func write(_ string: String, to url: URL) async throws {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.logger) var logger
    if !dryRun {
      try await fileClient.write(string: string, to: url)
    } else {
      logger.debug("Skipping, due to dry-run being passed.")
      logger.debug("\(string)")
    }
  }

  func write(_ currentVersion: CurrentVersionContainer) async throws {
    @Dependency(\.logger) var logger

    let version = try currentVersion.version.string(allowPreReleaseTag: allowPreReleaseTag)
    logger.debug("Version: \(version)")

    let template = currentVersion.usesOptionalType ? Template.optional(version) : Template.nonOptional(version)
    logger.trace("Template string: \(template)")

    try await write(template, to: currentVersion.targetUrl)
  }
}

@_spi(Internal)
public struct CurrentVersionContainer: Sendable {

  let targetUrl: URL
  let version: Version

  var usesOptionalType: Bool {
    switch version {
    case .string: return false
    case let .semVar(_, usesOptionalType): return usesOptionalType
    }
  }

  public enum Version: Sendable {
    case string(String)
    case semVar(SemVar, usesOptionalType: Bool = true)

    func string(allowPreReleaseTag: Bool) throws -> String {
      switch self {
      case let .string(string):
        return string
      case let .semVar(semVar, usesOptionalType: _):
        return semVar.versionString(withPreReleaseTag: allowPreReleaseTag)
      }
    }
  }
}

extension CliClient.SharedOptions {

  func build(_ environment: [String: String]) async throws -> String {
    try await run { currentVersion in
      try await write(currentVersion)
    }
  }

  func bump(_ type: CliClient.BumpOption?) async throws -> String {
    guard let type else {
      return try await generate()
    }

    return try await run { container in

      @Dependency(\.logger) var logger

      switch container.version {
      case .string: // When we did not parse a semVar, just write whatever we parsed for the current version.
        logger.debug("Failed to parse semvar, but got current version string.")
        try await write(container)

      case let .semVar(semVar, usesOptionalType: usesOptionalType):
        logger.debug("Semvar prior to bumping: \(semVar)")
        let bumped = semVar.bump(type, preRelease: nil) // preRelease is already set on semVar.
        let version = bumped.versionString(withPreReleaseTag: allowPreReleaseTag)
        logger.debug("Bumped version: \(version)")
        let template = usesOptionalType ? Template.optional(version) : Template.build(version)
        try await write(template, to: container.targetUrl)
      }
    }
  }

  func generate() async throws -> String {
    try await run { currentVersion in
      try await write(currentVersion)
    }
  }
}
