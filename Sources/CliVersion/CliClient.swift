import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Dependencies
import DependenciesMacros
import ShellClient

public extension DependencyValues {

  var cliClient: CliClient {
    get { self[CliClient.self] }
    set { self[CliClient.self] = newValue }
  }
}

@DependencyClient
public struct CliClient {
  public var build: @Sendable (BuildOptions) throws -> String
  public var generate: @Sendable (GenerateOptions) throws -> String
  public var update: @Sendable (UpdateOptions) throws -> String
}

extension CliClient: DependencyKey {
  public static let testValue: CliClient = Self()

  public static func live(environment: [String: String]) -> Self {
    .init(
      build: { try $0.run(environment) },
      generate: { try $0.run() },
      update: { try $0.run() }
    )
  }

  public static var liveValue: CliClient {
    .live(environment: ProcessInfo.processInfo.environment)
  }
}

public extension CliClient {

  // TODO: Use Int for `verbose`.
  struct SharedOptions: Sendable {
    let dryRun: Bool
    let fileName: String
    let target: String
    let verbose: Bool

    public init(
      dryRun: Bool = false,
      fileName: String,
      target: String,
      verbose: Bool = true
    ) {
      self.dryRun = dryRun
      self.fileName = fileName
      self.target = target
      self.verbose = verbose
    }
  }

  struct BuildOptions: Sendable {
    let gitDirectory: String?
    let shared: SharedOptions

    public init(
      gitDirectory: String? = nil,
      shared: SharedOptions
    ) {
      self.gitDirectory = gitDirectory
      self.shared = shared
    }
  }

  struct GenerateOptions: Sendable {
    let shared: SharedOptions

    public init(shared: SharedOptions) {
      self.shared = shared
    }
  }

  struct UpdateOptions: Sendable {
    let gitDirectory: String?
    let shared: SharedOptions

    public init(
      gitDirectory: String? = nil,
      shared: SharedOptions
    ) {
      self.gitDirectory = gitDirectory
      self.shared = shared
    }
  }
}

// MARK: Private

@_spi(Internal)
public extension CliClient.SharedOptions {
  var fileUrl: URL {
    url(for: target).appendingPathComponent(fileName)
  }

  func parseTarget() throws -> URL {
    let targetUrl = fileUrl
      .deletingLastPathComponent()
      .deletingLastPathComponent()

    guard targetUrl.lastPathComponent == "Sources" else {
      return url(for: "Sources")
        .appendingPathComponent(target)
        .appendingPathComponent(fileName)
    }
    return fileUrl
  }

  @discardableResult
  func run<T>(
    _ operation: () throws -> T
  ) rethrows -> T {
    try withDependencies {
      $0.logger.logLevel = .init(verbose: verbose)
    } operation: {
      try operation()
    }
  }
}

private extension CliClient.BuildOptions {

  func run(_ environment: [String: String]) throws -> String {
    try shared.run {
      @Dependency(\.gitVersionClient) var gitVersion
      @Dependency(\.fileClient) var fileClient
      @Dependency(\.logger) var logger

      let gitDirectory = gitDirectory ?? environment["PWD"]

      guard let gitDirectory else {
        throw CliClientError.gitDirectoryNotFound
      }

      logger.debug("Building with git directory: \(gitDirectory)")

      let fileUrl = shared.fileUrl
      logger.debug("File url: \(fileUrl.cleanFilePath)")

      let currentVersion = try gitVersion.currentVersion(in: gitDirectory)

      let fileContents = buildTemplate
        .replacingOccurrences(of: "nil", with: "\"\(currentVersion)\"")

      try fileClient.write(string: fileContents, to: fileUrl)

      return fileUrl.cleanFilePath
    }
  }
}

private extension CliClient.GenerateOptions {

  func run() throws -> String {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.logger) var logger

    let targetUrl = try shared.parseTarget()

    logger.debug("Generate target url: \(targetUrl.cleanFilePath)")

    guard !fileClient.fileExists(targetUrl) else {
      throw CliClientError.fileExists(path: targetUrl.cleanFilePath)
    }

    if !shared.dryRun {
      try fileClient.write(string: optionalTemplate, to: targetUrl)
    } else {
      logger.debug("Skipping, due to dry-run being passed.")
    }
    return targetUrl.cleanFilePath
  }
}

private extension CliClient.UpdateOptions {

  func run() throws -> String {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.gitVersionClient) var gitVersionClient
    @Dependency(\.logger) var logger

    let targetUrl = try shared.parseTarget()
    logger.debug("Target url: \(targetUrl.cleanFilePath)")

    let currentVersion = try gitVersionClient.currentVersion(in: gitDirectory)

    let fileContents = optionalTemplate
      .replacingOccurrences(of: "nil", with: "\"\(currentVersion)\"")

    if !shared.dryRun {
      try fileClient.write(string: fileContents, to: targetUrl)
    } else {
      logger.debug("Skipping due to dry run being passed.")
      logger.debug("Parsed version: \(currentVersion)")
    }
    return targetUrl.cleanFilePath
  }
}

private let optionalTemplate = """
// Do not set this variable, it is set during the build process.
let VERSION: String? = nil
"""

private let buildTemplate = """
// Do not set this variable, it is set during the build process.
let VERSION: String = nil
"""

enum CliClientError: Error {
  case gitDirectoryNotFound
  case fileExists(path: String)
}
