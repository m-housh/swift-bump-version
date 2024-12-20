import ArgumentParser
import CliVersion
import Dependencies
import Foundation
import ShellClient

extension CliVersionCommand {
  struct Generate: ParsableCommand {
    static var configuration: CommandConfiguration = .init(
      abstract: "Generates a version file in a command line tool that can be set via the git tag or git sha.",
      discussion: "This command can be interacted with directly, outside of the plugin usage context.",
      version: VERSION ?? "0.0.0"
    )

    @OptionGroup var shared: SharedOptions

    // TODO: Use CliClient
    func run() throws {
      @Dependency(\.logger) var logger: Logger
      @Dependency(\.fileClient) var fileClient

      let targetUrl = parseTarget(shared.target)
      let fileUrl = targetUrl.appendingPathComponent(shared.fileName)

      let fileString = fileUrl.fileString()

      guard !FileManager.default.fileExists(atPath: fileUrl.absoluteString) else {
        logger.info("File already exists at path.")
        throw GenerationError.fileExists(path: fileString)
      }

      if !shared.dryRun {
        try fileClient.write(string: optionalTemplate, to: fileUrl)
        logger.info("Generated file at: \(fileString)")
      } else {
        logger.info("Would generate file at: \(fileString)")
      }
    }
  }
}

private enum GenerationError: Error {
  case fileExists(path: String)
}
