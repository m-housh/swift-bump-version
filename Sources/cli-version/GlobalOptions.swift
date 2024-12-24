import ArgumentParser
@_spi(Internal) import CliClient
import ConfigurationClient
import Dependencies
import Foundation
import Rainbow

struct GlobalOptions: ParsableArguments {

  @OptionGroup
  var configOptions: ConfigurationOptions

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

  @Argument(
    help: """
    Arguments / options used for custom pre-release, options / flags must proceed a '--' in
    the command. These are ignored if the `--custom` flag is not set.
    """
  )
  var extraOptions: [String] = []

}

struct ConfigurationOptions: ParsableArguments {
  @Option(
    name: .shortAndLong,
    help: "Specify the path to a configuration file.",
    completion: .file(extensions: ["json"])
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

  @Flag(
    name: .long,
    help: """
    Apply custom pre-release suffix, using extra options / arguments passed in after a '--'.
    """
  )
  var customPreRelease: Bool = false

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
