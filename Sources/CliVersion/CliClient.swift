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

/// Handles the command-line commands.
@DependencyClient
public struct CliClient: Sendable {

  /// Build and update the version based on the git tag, or branch + sha.
  public var build: @Sendable (SharedOptions) async throws -> String

  /// Bump the existing version.
  public var bump: @Sendable (BumpOption, SharedOptions) async throws -> String

  /// Generate a version file with an optional version that can be set manually.
  public var generate: @Sendable (SharedOptions) async throws -> String

  /// Update a version file manually.
  public var update: @Sendable (SharedOptions) async throws -> String

  public enum BumpOption: Sendable, CaseIterable {
    case major, minor, patch
  }

  // TODO: Use Int for `verbose`.
  public struct SharedOptions: Equatable, Sendable {
    let gitDirectory: String?
    let dryRun: Bool
    let fileName: String
    let target: String
    let verbose: Bool

    public init(
      gitDirectory: String? = nil,
      dryRun: Bool = false,
      fileName: String = "Version.swift",
      target: String,
      verbose: Bool = true
    ) {
      self.gitDirectory = gitDirectory
      self.dryRun = dryRun
      self.fileName = fileName
      self.target = target
      self.verbose = verbose
    }
  }

}

extension CliClient: DependencyKey {
  public static let testValue: CliClient = Self()

  public static func live(environment: [String: String]) -> Self {
    .init(
      build: { try await $0.build(environment) },
      bump: { try await $1.bump($0) },
      generate: { try await $0.generate() },
      update: { try await $0.update() }
    )
  }

  public static var liveValue: CliClient {
    .live(environment: ProcessInfo.processInfo.environment)
  }
}

// MARK: Private

@_spi(Internal)
public extension CliClient.SharedOptions {

  var fileUrl: URL {
    let target = self.target.hasPrefix(".") ? String(self.target.dropFirst()) : self.target
    let targetHasSources = target.hasPrefix("Sources") || target.hasPrefix("/Sources")

    var url = url(for: gitDirectory ?? (targetHasSources ? target : "Sources"))
    if gitDirectory != nil {
      if !targetHasSources {
        url.appendPathComponent("Sources")
      }
      url.appendPathComponent(target)
    }
    url.appendPathComponent(fileName)
    return url
  }

  @discardableResult
  func run<T>(
    _ operation: () async throws -> T
  ) async rethrows -> T {
    try await withDependencies {
      $0.logger.logLevel = .init(verbose: verbose)
    } operation: {
      try await operation()
    }
  }
}

private extension CliClient.SharedOptions {

  func build(_ environment: [String: String]) async throws -> String {
    try await run {
      @Dependency(\.gitVersionClient) var gitVersion
      @Dependency(\.fileClient) var fileClient
      @Dependency(\.logger) var logger

      let gitDirectory = gitDirectory ?? environment["PWD"]

      guard let gitDirectory else {
        throw CliClientError.gitDirectoryNotFound
      }

      logger.debug("Building with git directory: \(gitDirectory)")

      let fileUrl = self.fileUrl
      logger.debug("File url: \(fileUrl.cleanFilePath)")

      let currentVersion = try await gitVersion.currentVersion(in: gitDirectory)

      let fileContents = Template.build(currentVersion)

      try await fileClient.write(string: fileContents, to: fileUrl)

      return fileUrl.cleanFilePath
    }
  }

  func bump(_ type: CliClient.BumpOption) async throws -> String {
    try await run {
      @Dependency(\.fileClient) var fileClient
      @Dependency(\.logger) var logger

      let targetUrl = fileUrl

      logger.debug("Bump target url: \(targetUrl.cleanFilePath)")

      let contents = try await fileClient.read(fileUrl)
      let versionLine = contents.split(separator: "\n")
        .first { $0.hasPrefix("let VERSION:") }

      guard let versionLine else {
        throw CliClientError.failedToParseVersionFile
      }

      let isOptional = versionLine.contains("String?")
      let versionString = versionLine.split(separator: "let VERSION: \(isOptional ? "String?" : "String") = ").last
      guard let versionString else {
        throw CliClientError.failedToParseVersionFile
      }

      let parts = String(versionString).split(separator: ".")
      logger.debug("Version parts: \(parts)")

      // TODO: Better error.
      guard parts.count == 3 else {
        throw CliClientError.failedToParseVersionFile
      }

      var major = Int(String(parts[0])) ?? 0
      var minor = Int(String(parts[1])) ?? 0
      var patch = Int(String(parts[2])) ?? 0

      type.bump(major: &major, minor: &minor, patch: &patch)

      let version = "\(major).\(minor).\(patch)"
      logger.debug("Bumped version: \(version)")

      let template = isOptional ? Template.optional(version) : Template.build(version)

      if !dryRun {
        try await fileClient.write(string: template, to: targetUrl)
      } else {
        logger.debug("Skipping, due to dry-run being passed.")
      }

      return targetUrl.cleanFilePath
    }
  }

  func generate(_ version: String? = nil) async throws -> String {
    try await run {
      @Dependency(\.fileClient) var fileClient
      @Dependency(\.logger) var logger

      let targetUrl = fileUrl

      logger.debug("Generate target url: \(targetUrl.cleanFilePath)")

      guard !fileClient.fileExists(targetUrl) else {
        throw CliClientError.fileExists(path: targetUrl.cleanFilePath)
      }

      let template = Template.optional(version)

      if !dryRun {
        try await fileClient.write(string: template, to: targetUrl)
      } else {
        logger.debug("Skipping, due to dry-run being passed.")
      }
      return targetUrl.cleanFilePath
    }
  }

  func update() async throws -> String {
    @Dependency(\.gitVersionClient) var gitVersionClient
    return try await generate(gitVersionClient.currentVersion(in: gitDirectory))
  }
}

@_spi(Internal)
public extension CliClient.BumpOption {

  func bump(
    major: inout Int,
    minor: inout Int,
    patch: inout Int
  ) {
    switch self {
    case .major:
      major += 1
      minor = 0
      patch = 0
    case .minor:
      minor += 1
      patch = 0
    case .patch:
      patch += 1
    }
  }
}

@_spi(Internal)
public struct Template {
  let type: TemplateType
  let version: String?

  enum TemplateType: String {
    case optionalString = "String?"
    case string = "String"
  }

  var value: String {
    return """
    // Do not set this variable, it is set during the build process.
    let VERSION: \(type.rawValue) = \(version ?? "nil")

    """
  }

  public static func build(_ version: String? = nil) -> String {
    Self(type: .string, version: version).value
  }

  public static func optional(_ version: String? = nil) -> String {
    Self(type: .optionalString, version: version).value
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
  case failedToParseVersionFile
}
