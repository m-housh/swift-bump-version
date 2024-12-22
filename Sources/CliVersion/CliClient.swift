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

  static let defaultFileName = "Version.swift"

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

  public struct SharedOptions: Equatable, Sendable {

    let allowPreReleaseTag: Bool
    let dryRun: Bool
    let gitDirectory: String?
    let logLevel: Logger.Level
    let target: String

    public init(
      allowPreReleaseTag: Bool = false,
      gitDirectory: String? = nil,
      dryRun: Bool = false,
      target: String,
      logLevel: Logger.Level = .debug
    ) {
      self.allowPreReleaseTag = allowPreReleaseTag
      self.gitDirectory = gitDirectory
      self.dryRun = dryRun
      self.target = target
      self.logLevel = logLevel
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

  func fileUrl() async throws -> URL {
    @Dependency(\.fileClient) var fileClient

    let target = self.target.hasPrefix(".") ? String(self.target.dropFirst()) : self.target
    let targetHasSources = target.hasPrefix("Sources") || target.hasPrefix("/Sources")

    var url = url(for: gitDirectory ?? (targetHasSources ? target : "Sources"))

    if gitDirectory != nil {
      if !targetHasSources {
        url.appendPathComponent("Sources")
      }
      url.appendPathComponent(target)
    }

    let isDirectory = try await fileClient.isDirectory(url.cleanFilePath)

    if isDirectory {
      url.appendPathComponent(CliClient.defaultFileName)
    }

    return url
  }

  @discardableResult
  func run<T>(
    _ operation: () async throws -> T
  ) async rethrows -> T {
    try await withDependencies {
      $0.logger.logLevel = logLevel
    } operation: {
      try await operation()
    }
  }

  func write(_ string: String, to url: URL) async throws {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.logger) var logger
    if !dryRun {
      try await fileClient.write(string: string, to: url)
    } else {
      logger.debug("Skipping, due to dry-run being passed.")
      logger.debug("\(string)")
    }
  }
}

private extension CliClient.SharedOptions {

  func gitVersion() async throws -> GitClient.Version {
    @Dependency(\.gitClient) var gitClient

    if let exactMatch = try? await gitClient.version(.init(
      gitDirectory: gitDirectory,
      style: .tag(exactMatch: true)
    )) {
      return exactMatch
    } else if let partialMatch = try? await gitClient.version(.init(
      gitDirectory: gitDirectory,
      style: .tag(exactMatch: false)
    )) {
      return partialMatch
    } else {
      return try await gitClient.version(.init(
        gitDirectory: gitDirectory,
        style: .branch(commitSha: true)
      ))
    }
  }

  func gitSemVar() async throws -> SemVar {
    @Dependency(\.gitClient) var gitClient

    let version = try await gitVersion()

    guard let semVar = version.semVar else {
      return .init(preRelease: version.description)
    }

    if allowPreReleaseTag, semVar.preRelease == nil {
      let branchVersion = try await gitClient.version(.init(
        gitDirectory: gitDirectory,
        style: .branch(commitSha: true)
      ))
      return .init(
        major: semVar.major,
        minor: semVar.minor,
        patch: semVar.patch,
        preRelease: branchVersion.description
      )
    }
    return semVar
  }

  func build(_ environment: [String: String]) async throws -> String {
    try await run {
      @Dependency(\.gitClient) var gitVersion
      @Dependency(\.fileClient) var fileClient
      @Dependency(\.logger) var logger

      let fileUrl = try await self.fileUrl()
      logger.debug("File url: \(fileUrl.cleanFilePath)")

      let currentVersion = try await gitVersion.currentVersion(in: gitDirectory)
      logger.debug("Git version: \(currentVersion)")

      let fileContents = Template.build(currentVersion)

      try await write(fileContents, to: fileUrl)

      return fileUrl.cleanFilePath
    }
  }

  private func getVersionString() async throws -> (version: String, usesOptionalType: Bool) {
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.gitClient) var gitVersionClient
    @Dependency(\.logger) var logger

    let targetUrl = try await fileUrl()

    guard fileClient.fileExists(targetUrl) else {
      // Get the latest tag, not requiring an exact tag set on the commit.
      // This will return a tag, that may have some more data on the patch
      // portion of the tag, such as: 0.1.1-4-g59bc977
      let version = try await gitVersionClient.currentVersion(in: gitDirectory, exactMatch: false)
      // TODO: Not sure what to do for the uses optional value here??
      return (version, false)
    }

    let contents = try await fileClient.read(targetUrl)
    let versionLine = contents.split(separator: "\n")
      .first { $0.hasPrefix("let VERSION:") }

    guard let versionLine else {
      throw CliClientError.failedToParseVersionFile
    }
    logger.debug("Version line: \(versionLine)")

    let isOptional = versionLine.contains("String?")
    logger.debug("Uses optional: \(isOptional)")

    let versionString = versionLine.split(separator: "let VERSION: \(isOptional ? "String?" : "String") = ").last
    guard let versionString else {
      throw CliClientError.failedToParseVersionFile
    }
    return (String(versionString), isOptional)
  }

  private func getSemVar(_ version: String, _ bump: CliClient.BumpOption) throws -> SemVar {
    let semVar = SemVar(string: version) ?? .init()
    return semVar.bump(bump)
  }

  func bump(_ type: CliClient.BumpOption) async throws -> String {
    try await run {
      @Dependency(\.fileClient) var fileClient
      @Dependency(\.logger) var logger

      let targetUrl = try await fileUrl()

      logger.debug("Bump target url: \(targetUrl.cleanFilePath)")

      let (versionString, usesOptional) = try await getVersionString()
      let semVar = try getSemVar(versionString, type)
      let version = semVar.versionString(allowPrerelease: allowPreReleaseTag)
      logger.debug("Bumped version: \(version)")

      let template = usesOptional ? Template.optional(version) : Template.build(version)
      try await write(template, to: targetUrl)
      return targetUrl.cleanFilePath
    }
  }

  func generate(_ version: String? = nil) async throws -> String {
    try await run {
      @Dependency(\.fileClient) var fileClient
      @Dependency(\.logger) var logger

      let targetUrl = try await fileUrl()

      logger.debug("Generate target url: \(targetUrl.cleanFilePath)")

      guard !fileClient.fileExists(targetUrl) else {
        throw CliClientError.fileExists(path: targetUrl.cleanFilePath)
      }

      let template = Template.optional(version)
      try await write(template, to: targetUrl)
      return targetUrl.cleanFilePath
    }
  }

  func update() async throws -> String {
    @Dependency(\.gitClient) var gitVersionClient
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
public struct Template: Sendable {
  let type: TemplateType
  let version: String?

  enum TemplateType: String, Sendable {
    case optionalString = "String?"
    case string = "String"
  }

  var value: String {
    let versionString = version != nil ? "\"\(version!)\"" : "nil"
    return """
    // Do not set this variable, it is set during the build process.
    let VERSION: \(type.rawValue) = \(versionString)
    """
  }

  public static func build(_ version: String? = nil) -> String {
    nonOptional(version)
  }

  public static func nonOptional(_ version: String? = nil) -> String {
    Self(type: .string, version: version).value
  }

  public static func optional(_ version: String? = nil) -> String {
    Self(type: .optionalString, version: version).value
  }
}

enum CliClientError: Error {
  case gitDirectoryNotFound
  case fileExists(path: String)
  case failedToParseVersionFile
}
