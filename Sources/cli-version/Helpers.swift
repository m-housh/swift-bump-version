import ArgumentParser
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

// TODO: Use Int for `verbose`.
struct SharedOptions: ParsableArguments {

  @Argument(help: "The target for the version file.")
  var target: String

  @Option(
    name: .customLong("filename"),
    help: "Specify the file name for the version file."
  )
  var fileName: String = "Version.swift"

  @Flag(name: .customLong("dry-run"))
  var dryRun: Bool = false

  @Flag(name: .long, help: "Increase logging level.")
  var verbose: Bool = false
}
