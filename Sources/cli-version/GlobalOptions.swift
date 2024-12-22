import ArgumentParser
@_spi(Internal) import CliClient
import Dependencies
import Foundation

func parseTarget(_ target: String) -> URL {
  let url = URL(fileURLWithPath: target)
  let urlTest = url
    .deletingLastPathComponent()

  guard urlTest.lastPathComponent == "Sources" else {
    return URL(fileURLWithPath: "Sources")
      .appendingPathComponent(target)
  }
  return url
}

extension URL {
  func fileString() -> String {
    absoluteString
      .replacingOccurrences(of: "file://", with: "")
  }
}

let optionalTemplate = """
// Do not set this variable, it is set during the build process.
let VERSION: String? = nil

"""

let buildTemplate = """
// Do not set this variable, it is set during the build process.
let VERSION: String = nil

"""

struct GlobalOptions: ParsableArguments {

  @Option(
    name: .customLong("git-directory"),
    help: "The git directory for the version (default: current directory)"
  )
  var gitDirectory: String?

  @Option(
    name: .shortAndLong,
    help: "The target for the version file."
  )
  var target: String

  @Option(
    name: .customLong("filename"),
    help: "Specify the file name for the version file in the target."
  )
  var fileName: String = "Version.swift"

  @Flag(name: .customLong("dry-run"))
  var dryRun: Bool = false

  @Flag(
    name: .shortAndLong,
    help: "Increase logging level, can be passed multiple times (example: -vvv)."
  )
  var verbose: Int
}

extension GlobalOptions {

  var shared: CliClient.SharedOptions {
    .init(
      gitDirectory: gitDirectory,
      dryRun: dryRun,
      target: target,
      logLevel: .init(verbose: verbose)
    )
  }

  func run(_ operation: () async throws -> Void) async throws {
    try await withDependencies {
      $0.fileClient = .liveValue
      $0.gitClient = .liveValue
      $0.cliClient = .liveValue
    } operation: {
      try await operation()
    }
  }
}
