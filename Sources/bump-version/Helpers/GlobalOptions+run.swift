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

extension GlobalOptions {

  func runClient<T>(
    _ keyPath: KeyPath<CliClient, @Sendable (CliClient.SharedOptions) async throws -> T>,
    command: String
  ) async throws -> T {
    try await withSetupDependencies {
      @Dependency(\.cliClient) var cliClient
      return try await cliClient[keyPath: keyPath](shared(command: command))
    }
  }

  func runClient<A, T>(
    _ keyPath: KeyPath<CliClient, @Sendable (A, CliClient.SharedOptions) async throws -> T>,
    command: String,
    args: A
  ) async throws -> T {
    try await withSetupDependencies {
      @Dependency(\.cliClient) var cliClient
      return try await cliClient[keyPath: keyPath](args, shared(command: command))
    }
  }

  func run(
    _ keyPath: KeyPath<CliClient, @Sendable (CliClient.SharedOptions) async throws -> String>,
    command: String
  ) async throws {
    let output = try await runClient(keyPath, command: command)
    print(output)
  }

  func run<T>(
    _ keyPath: KeyPath<CliClient, @Sendable (T, CliClient.SharedOptions) async throws -> String>,
    command: String,
    args: T
  ) async throws {
    let output = try await runClient(keyPath, command: command, args: args)
    print(output)
  }

  func shared(command: String) throws -> CliClient.SharedOptions {
    try .init(
      allowPreReleaseTag: !configOptions.semvarOptions.preRelease.disablePreRelease,
      dryRun: dryRun,
      gitDirectory: gitDirectory,
      loggingOptions: .init(command: command, verbose: verbose),
      target: configOptions.target(),
      branch: .init(includeCommitSha: configOptions.commitSha),
      semvar: configOptions.semvarOptions(extraOptions: extraOptions),
      configurationFile: configOptions.configurationFile
    )
  }

}

private extension TargetOptions {
  func configTarget() throws -> Configuration.Target? {
    guard let path else {
      guard let module else {
        return nil
      }
      return .init(module: .init(module, fileName: fileName))
    }
    return .init(path: path)
  }
}

extension PreReleaseOptions {

  func configPreReleaseStrategy(includeCommitSha: Bool, extraOptions: [String]) throws -> Configuration.PreRelease? {
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

  func configSemVarOptions(includeCommitSha: Bool, extraOptions: [String]) throws -> Configuration.SemVar {
    try .init(
      preRelease: preRelease.configPreReleaseStrategy(includeCommitSha: includeCommitSha, extraOptions: extraOptions),
      requireExistingFile: requireExistingFile,
      requireExistingSemVar: requireExistingSemvar
    )
  }
}

extension ConfigurationOptions {

  func target() throws -> Configuration.Target? {
    try targetOptions.configTarget()
  }

  func semvarOptions(extraOptions: [String]) throws -> Configuration.SemVar {
    try semvarOptions.configSemVarOptions(includeCommitSha: commitSha, extraOptions: extraOptions)
  }
}

struct ExtraOptionsEmpty: Error {}
