import ArgumentParser
@_spi(Internal) import CliClient
import ConfigurationClient
import Dependencies
import Foundation
import Rainbow

struct GlobalOptions<Child: ParsableArguments>: ParsableArguments {

  @OptionGroup var targetOptions: TargetOptions
  @OptionGroup var child: Child

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

struct Empty: ParsableArguments {}

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

struct PreReleaseOptions: ParsableArguments {
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
    name: .shortAndLong,
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

typealias GlobalSemVarOptions = GlobalOptions<SemVarOptions>
typealias GlobalBranchOptions = GlobalOptions<Empty>

extension GlobalSemVarOptions {
  func shared() throws -> CliClient.SharedOptions {
    try shared(.semVar(child.semVarOptions()))
  }
}

extension GlobalBranchOptions {
  func shared() throws -> CliClient.SharedOptions {
    try shared(.branchAndCommit)
  }
}

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

  func shared(_ versionStrategy: CliClient.VersionStrategy) throws -> CliClient.SharedOptions {
    try .init(
      dryRun: dryRun,
      gitDirectory: gitDirectory,
      logLevel: .init(verbose: verbose),
      target: targetOptions.target(),
      versionStrategy: versionStrategy
    )
  }

}

// MARK: - Helpers

private extension TargetOptions {
  func target() throws -> String {
    guard let path else {
      guard let module else {
        print("Neither target path or module was set.")
        throw InvalidTargetOption()
      }

      return "\(module)/\(fileName)"
    }
    return path
  }

  struct InvalidTargetOption: Error {}

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

  func preReleaseStrategy() throws -> CliClient.PreReleaseStrategy? {
    guard let custom else {
      if useBranchAsPreRelease {
        return .branchAndCommit
      } else if useTagAsPreRelease {
        return .tag
      } else {
        return nil
      }
    }

    if useBranchAsPreRelease {
      return .custom(custom, .branchAndCommit)
    } else if useTagAsPreRelease {
      return .custom(custom, .tag)
    } else {
      return .custom(custom, nil)
    }
  }

  func configPreReleaseStrategy() throws -> Configuration.PreReleaseStrategy? {
    guard let custom else {
      if useBranchAsPreRelease {
        return .branch()
      } else if useTagAsPreRelease {
        return .gitTag
      } else {
        return nil
      }
    }

    if useBranchAsPreRelease {
      return .customBranchPrefix(custom)
    } else if useTagAsPreRelease {
      return .customGitTagPrefix(custom)
    } else {
      return .custom(custom)
    }
  }
}

extension SemVarOptions {
  func semVarOptions() throws -> CliClient.VersionStrategy.SemVarOptions {
    try .init(
      preReleaseStrategy: preRelease.preReleaseStrategy(),
      requireExistingFile: requireExistingFile,
      requireExistingSemVar: requireExistingSemvar
    )
  }

  func configSemVarOptions() throws -> Configuration.SemVar {
    try .init(
      preRelease: preRelease.configPreReleaseStrategy(),
      requireExistingFile: requireExistingFile,
      requireExistingSemVar: requireExistingSemvar
    )
  }

}
