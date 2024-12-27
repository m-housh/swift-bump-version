import CliClient
import ConfigurationClient
import Dependencies
import FileClient
import GitClient

@discardableResult
func withSetupDependencies<T>(
  _ operation: () async throws -> T
) async throws -> T {
  try await withDependencies {
    $0.fileClient = .liveValue
    $0.gitClient = .liveValue
    $0.cliClient = .liveValue
    $0.configurationClient = .liveValue
  } operation: {
    try await operation()
  }
}

extension CliClient.SharedOptions {
  func runClient<T>(
    _ keyPath: KeyPath<CliClient, @Sendable (Self) async throws -> T>
  ) async throws -> T {
    try await withSetupDependencies {
      @Dependency(\.cliClient) var cliClient
      return try await cliClient[keyPath: keyPath](self)
    }
  }

  func runClient<A, T>(
    _ keyPath: KeyPath<CliClient, @Sendable (A, Self) async throws -> T>,
    args: A
  ) async throws -> T {
    try await withSetupDependencies {
      @Dependency(\.cliClient) var cliClient
      return try await cliClient[keyPath: keyPath](args, self)
    }
  }

}

extension GlobalOptions {

  func run(
    _ keyPath: KeyPath<CliClient, @Sendable (CliClient.SharedOptions) async throws -> String>,
    command: String
  ) async throws {
    let output = try await shared(command: command).runClient(keyPath)
    print(output)
  }

  func run<T>(
    _ keyPath: KeyPath<CliClient, @Sendable (T, CliClient.SharedOptions) async throws -> String>,
    command: String,
    args: T
  ) async throws {
    let output = try await shared(command: command).runClient(keyPath, args: args)
    print(output)
  }

  func shared(command: String) throws -> CliClient.SharedOptions {
    try configOptions.shared(
      command: command,
      dryRun: dryRun,
      extraOptions: extraOptions,
      gitDirectory: projectDirectory,
      verbose: verbose
    )
  }
}

private extension TargetOptions {
  func configTarget() throws -> Configuration.Target? {
    guard let targetFilePath else {
      guard let targetModule else {
        return nil
      }
      return .init(module: .init(targetModule, fileName: targetFileName))
    }
    return .init(path: targetFilePath)
  }
}

extension PreReleaseOptions {

  func configPreReleaseStrategy(
    includeCommitSha: Bool,
    extraOptions: [String]
  ) throws -> Configuration.PreRelease? {
    if useBranchAsPreRelease {
      return .init(prefix: preReleasePrefix, strategy: .branch(includeCommitSha: includeCommitSha))
    } else if useTagAsPreRelease {
      return .init(prefix: preReleasePrefix, strategy: .gitTag)
    } else if customPreRelease {
      guard extraOptions.count > 0 else {
        throw ExtraOptionsEmpty()
      }
      return .init(prefix: preReleasePrefix, strategy: .command(arguments: extraOptions))
    } else if let preReleasePrefix {
      return .init(prefix: preReleasePrefix, strategy: nil)
    }
    return nil
  }
}

extension SemVarOptions {

  func parseStrategy(extraOptions: [String]) throws -> Configuration.SemVar.Strategy? {
    @Dependency(\.logger) var logger

    guard customCommand else {
      guard gitTag else { return nil }
      return .gitTag(exactMatch: requireExactMatch)
    }
    guard extraOptions.count > 0 else {
      logger.error("""
      Extra options are empty, this does not make sense when using a custom command
      strategy.
      """)
      throw ExtraOptionsEmpty()
    }
    return .command(arguments: extraOptions)
  }

  func configSemVarOptions(
    includeCommitSha: Bool,
    extraOptions: [String]
  ) throws -> Configuration.SemVar {
    @Dependency(\.logger) var logger

    if customCommand && preRelease.customPreRelease {
      logger.warning("""
      Custom pre-release can not be used at same time as custom command.
      Ignoring pre-release...
      """)
    }

    return try .init(
      allowPreRelease: !preRelease.disablePreRelease,
      preRelease: customCommand ? nil : preRelease.configPreReleaseStrategy(
        includeCommitSha: includeCommitSha,
        extraOptions: extraOptions
      ),
      // Use nil here if false, which makes them not get used in json / file output, which makes
      // user config smaller.
      requireExistingFile: requireExistingFile ? true : nil,
      requireExistingSemVar: requireExistingSemvar ? true : nil,
      strategy: parseStrategy(extraOptions: extraOptions)
    )
  }
}

extension ConfigurationOptions {

  func target() throws -> Configuration.Target? {
    try targetOptions.configTarget()
  }

  func semvarOptions(
    extraOptions: [String]
  ) throws -> Configuration.SemVar {
    try semvarOptions.configSemVarOptions(
      includeCommitSha: commitSha,
      extraOptions: extraOptions
    )
  }

  private func configurationToMerge(extraOptions: [String]) throws -> Configuration {
    try .init(
      target: target(),
      strategy: semvarOptions.gitTag
        ? .semvar(semvarOptions(extraOptions: extraOptions))
        : .branch(includeCommitSha: commitSha)
    )
  }

  func shared(
    command: String,
    dryRun: Bool = true,
    extraOptions: [String] = [],
    gitDirectory: String? = nil,
    verbose: Int = 0
  ) throws -> CliClient.SharedOptions {
    try .init(
      allowPreReleaseTag: !semvarOptions.preRelease.disablePreRelease,
      dryRun: dryRun,
      projectDirectory: gitDirectory,
      loggingOptions: .init(command: command, verbose: verbose),
      configurationToMerge: configurationToMerge(extraOptions: extraOptions),
      configurationFile: configurationFile,
      requireConfigurationFile: requireConfiguration
    )
  }
}

struct ExtraOptionsEmpty: Error {}
