import ConfigurationClient
import CustomDump
import Dependencies
import FileClient
import Foundation
import GitClient
import LoggingExtensions

extension CliClient.SharedOptions {

  /// All cli-client calls should run through this, it set's up logging,
  /// loads configuration, and generates the current version based on the
  /// configuration.
  @discardableResult
  func run(
    _ operation: (VersionContainer) async throws -> Void
  ) async rethrows -> String {
    try await loggingOptions.withLogger {
      // Load the default configuration, if it exists.
      try await withMergedConfiguration { configuration in
        @Dependency(\.logger) var logger

        guard let strategy = configuration.strategy else {
          throw CliClientError.strategyNotFound(configuration: configuration)
        }

        logger.dump(configuration, level: .trace) {
          "\nConfiguration: \($0)"
        }

        // This will fail if the target url is not set properly.
        let targetUrl = try configuration.targetUrl(gitDirectory: projectDirectory)
        logger.debug("Target: \(targetUrl.cleanFilePath)")

        // Perform the operation, which generates the new version and writes it.
        try await operation(
          .load(projectDirectory: projectDirectory, strategy: strategy, url: targetUrl)
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

    if configurationToMerge?.strategy?.branch != nil {
      logger.trace("Merging branch strategy.")
      // strategy = .branch(branch)
    } else if let semvar = configurationToMerge?.strategy?.semvar {
      logger.dump(semvar, level: .trace) {
        "Merging semvar strategy:\n\($0)"
      }
    }

    return try await configurationClient.withConfiguration(
      path: configurationFile,
      merging: configurationToMerge,
      strict: requireConfigurationFile,
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
    }
  }

  func write(_ currentVersion: VersionContainer) async throws {
    @Dependency(\.logger) var logger
    logger.trace("Begin writing version.")

    let hasChanges: Bool
    let targetUrl: URL
    let usesOptionalType: Bool
    let versionString: String?

    switch currentVersion {
    case let .branch(branch):
      hasChanges = branch.hasChanges
      targetUrl = branch.targetUrl
      usesOptionalType = branch.usesOptionalType
      versionString = branch.versionString
    case let .semvar(semvar):
      hasChanges = semvar.hasChanges
      targetUrl = semvar.targetUrl
      usesOptionalType = semvar.usesOptionalType
      versionString = semvar.versionString(withPreRelease: allowPreReleaseTag)
    }

    // if !hasChanges {
    //   logger.debug("No changes from loaded version, not writing next version.")
    //   return
    // }

    guard let versionString else {
      throw CliClientError.versionStringNotFound
    }

    // let version = try currentVersion.version.string(allowPreReleaseTag: allowPreReleaseTag)

    if !dryRun {
      logger.debug("Version: \(versionString)")
    } else {
      logger.info("Version: \(versionString)")
    }

    let template = usesOptionalType ? Template.optional(versionString) : Template.nonOptional(versionString)
    logger.trace("Template string: \(template)")

    try await write(template, to: targetUrl)
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

      switch container {
      case .branch: // When we did not parse a semvar, just write whatever we parsed for the current version.
        logger.debug("Failed to parse semvar, but got current version string.")
        try await write(container)

      case let .semvar(semvar):

        let version: SemVar?

        switch semvar.precedence ?? .default {
        case .file:
          version = semvar.loadedVersion ?? semvar.strategyVersion
        case .strategy:
          version = semvar.strategyVersion ?? semvar.loadedVersion
        }

        // let version = semvar.loadedVersion ?? semvar.nextVersion
        guard let version else {
          throw CliClientError.semVarNotFound(message: "Failed to parse a valid semvar to bump.")
        }
        logger.dump(version, level: .debug) { "Version prior to bumping:\n\($0)" }
        let bumped = version.bump(type)
        logger.dump(bumped, level: .trace) { "Bumped version:\n\($0)" }
        try await write(.semvar(semvar.withUpdateNextVersion(bumped)))
      }
    }
  }

  func generate() async throws -> String {
    try await run { currentVersion in
      try await write(currentVersion)
    }
  }
}
