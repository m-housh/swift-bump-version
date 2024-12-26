import ConfigurationClient
import CustomDump
import Dependencies
import FileClient
import Foundation
import GitClient

@_spi(Internal)
public extension CliClient.SharedOptions {

  /// All cli-client calls should run through this, it set's up logging,
  /// loads configuration, and generates the current version based on the
  /// configuration.
  @discardableResult
  func run(
    _ operation: (CurrentVersionContainer) async throws -> Void
  ) async rethrows -> String {
    try await loggingOptions.withLogger {
      // Load the default configuration, if it exists.
      try await withMergedConfiguration { configuration in
        @Dependency(\.logger) var logger

        var configurationString = ""
        customDump(configuration, to: &configurationString)
        logger.trace("\nConfiguration: \(configurationString)")

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

  // Merges any configuration set via the passed in options.
  @discardableResult
  func withMergedConfiguration<T>(
    operation: (Configuration) async throws -> T
  ) async throws -> T {
    @Dependency(\.configurationClient) var configurationClient
    @Dependency(\.logger) var logger

    var strategy: Configuration.VersionStrategy?

    if let branch {
      logger.trace("Merging branch strategy.")
      strategy = .branch(branch)
    } else if let semvar {
      logger.trace("Merging semvar strategy.")
      var semvarString = ""
      customDump(semvar, to: &semvarString)
      logger.trace("\(semvarString)")
      strategy = .semvar(semvar)
    }

    let configuration = Configuration(
      target: target,
      strategy: strategy
    )

    return try await configurationClient.withConfiguration(
      path: configurationFile,
      merging: configuration,
      operation: operation
    )
  }

  func write(_ string: String, to url: URL) async throws {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.logger) var logger
    if !dryRun {
      try await fileClient.write(string: string, to: url)
    } else {
      logger.debug("Skipping, due to dry-run being passed.")
      logger.debug("\n\(string)\n")
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
    case let .semvar(_, usesOptionalType): return usesOptionalType
    }
  }

  public enum Version: Sendable {
    case string(String)
    case semvar(SemVar, usesOptionalType: Bool = true)

    func string(allowPreReleaseTag: Bool) throws -> String {
      switch self {
      case let .string(string):
        return string
      case let .semvar(semvar, usesOptionalType: _):
        return semvar.versionString(withPreReleaseTag: allowPreReleaseTag)
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
      case .string: // When we did not parse a semvar, just write whatever we parsed for the current version.
        logger.debug("Failed to parse semvar, but got current version string.")
        try await write(container)

      case let .semvar(semvar, usesOptionalType: usesOptionalType):
        logger.debug("Semvar prior to bumping: \(semvar)")
        let bumped = semvar.bump(type)
        let version = bumped.versionString(withPreReleaseTag: allowPreReleaseTag)
        guard bumped != semvar else {
          logger.debug("No change, skipping.")
          return
        }
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
