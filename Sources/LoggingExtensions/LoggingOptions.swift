import Dependencies
import ShellClient

public struct LoggingOptions: Equatable, Sendable {

  let command: String
  let executableName: String
  let verbose: Int

  public init(
    executableName: String = "bump-version",
    command: String,
    verbose: Int
  ) {
    self.executableName = executableName
    self.command = command
    self.verbose = verbose
  }

  public func withLogger<T>(_ operation: () async throws -> T) async rethrows -> T {
    try await withDependencies {
      $0.logger = makeLogger()
      $0.logger.logLevel = .init(verbose: verbose)
    } operation: {
      try await operation()
    }
  }
}
