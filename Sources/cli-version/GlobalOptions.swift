import ArgumentParser
@_spi(Internal) import CliClient
import ConfigurationClient
import Dependencies
import Foundation
import Rainbow

struct GlobalOptions: ParsableArguments {

  @Option(
    name: .shortAndLong,
    help: "Specify the path to a configuration file."
  )
  var configurationFile: String?

  @OptionGroup var targetOptions: TargetOptions

  @OptionGroup var semvarOptions: SemVarOptions

  @Flag(
    name: .long,
    inversion: .prefixedNo,
    help: """
    Include the short commit sha in version or pre-release branch style output.
    """
  )
  var commitSha: Bool = true

  @Option(
    name: .customLong("git-directory"),
    help: "The git directory for the version (default: current directory)"
  )
  var gitDirectory: String?

  @Flag(
    name: .customLong("dry-run"),
    help: "Print's what would be written to a target version file."
  )
  var dryRun: Bool = false

  @Flag(
    name: .shortAndLong,
    help: "Increase logging level, can be passed multiple times (example: -vvv)."
  )
  var verbose: Int

}

struct TargetOptions: ParsableArguments {
  @Option(
    name: .shortAndLong,
    help: "Path to the version file, not required if module is set."
  )
  var path: String?

  @Option(
    name: .shortAndLong,
    help: "The target module name or directory path, not required if path is set."
  )
  var module: String?

  @Option(
    name: [.customShort("n"), .long],
    help: "The file name inside the target module, required if module is set."
  )
  var fileName: String = "Version.swift"

}

// TODO: Need to be able to pass in arguments for custom command pre-release option.

struct PreReleaseOptions: ParsableArguments {

  @Flag(
    name: .shortAndLong,
    help: ""
  )
  var disablePreRelease: Bool = false

  @Flag(
    name: [.customShort("s"), .customLong("pre-release-branch-style")],
    help: """
    Use branch name and commit sha for pre-release suffix, ignored if branch is set.
    """
  )
  var useBranchAsPreRelease: Bool = false

  @Flag(
    name: [.customShort("g"), .customLong("pre-release-git-tag-style")],
    help: """
    Use `git describe --tags` for pre-release suffix, ignored if branch is set.
    """
  )
  var useTagAsPreRelease: Bool = false

  @Option(
    name: .long,
    help: """
    Add / use a pre-release prefix string.
    """
  )
  var preReleasePrefix: String?

  @Option(
    name: .long,
    help: """
    Apply custom pre-release suffix, can also use branch or tag along with this
    option as a prefix, used if branch is not set. (example: \"rc\")
    """
  )
  var custom: String?

}

struct SemVarOptions: ParsableArguments {

  @Flag(
    name: .long,
    help: """
    Fail if an existing version file does not exist, \("ignored if:".yellow.bold) \("branch is set".italic).
    """
  )
  var requireExistingFile: Bool = false

  @Flag(
    name: .long,
    help: "Fail if a sem-var is not parsed from existing file or git tag, used if branch is not set."
  )
  var requireExistingSemvar: Bool = false

  @OptionGroup var preRelease: PreReleaseOptions
}

// TODO: Move these to global options.
extension CliClient.SharedOptions {

  func run(_ keyPath: KeyPath<CliClient, @Sendable (Self) async throws -> String>) async throws {
    try await withDependencies {
      $0.fileClient = .liveValue
      $0.gitClient = .liveValue
      $0.cliClient = .liveValue
    } operation: {
      @Dependency(\.cliClient) var cliClient
      let output = try await cliClient[keyPath: keyPath](self)
      print(output)
    }
  }

  func run<T>(
    _ keyPath: KeyPath<CliClient, @Sendable (T, Self) async throws -> String>,
    args: T
  ) async throws {
    try await withDependencies {
      $0.fileClient = .liveValue
      $0.gitClient = .liveValue
      $0.cliClient = .liveValue
    } operation: {
      @Dependency(\.cliClient) var cliClient
      let output = try await cliClient[keyPath: keyPath](args, self)
      print(output)
    }
  }
}

extension GlobalOptions {

  func shared() throws -> CliClient.SharedOptions {
    try .init(
      allowPreReleaseTag: !semvarOptions.preRelease.disablePreRelease,
      dryRun: dryRun,
      gitDirectory: gitDirectory,
      verbose: verbose,
      target: targetOptions.configTarget(),
      branch: .init(includeCommitSha: commitSha),
      semvar: semvarOptions.configSemVarOptions(),
      configurationFile: configurationFile
    )
  }

}

// MARK: - Helpers

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

  // FIX:
  func configPreReleaseStrategy() throws -> Configuration.PreRelease? {
    return nil
    // guard let custom else {
    //   if useBranchAsPreRelease {
    //     return .branch()
    //   } else if useTagAsPreRelease {
    //     return .gitTag
    //   } else {
    //     return nil
    //   }
    // }
    //
    // if useBranchAsPreRelease {
    //   return .customBranchPrefix(custom)
    // } else if useTagAsPreRelease {
    //   return .customGitTagPrefix(custom)
    // } else {
    //   return .custom(custom)
    // }
  }
}

extension SemVarOptions {

  func configSemVarOptions() throws -> Configuration.SemVar {
    try .init(
      preRelease: preRelease.configPreReleaseStrategy(),
      requireExistingFile: requireExistingFile,
      requireExistingSemVar: requireExistingSemvar
    )
  }

}
