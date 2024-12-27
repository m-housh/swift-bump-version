@_spi(Internal) import CliClient
import ConfigurationClient
import Dependencies
import FileClient
import Foundation
import GitClient
import Logging
import Testing
import TestSupport

@Suite("CliClientTests")
struct CliClientTests {

  @Test(
    arguments: TestArguments.testCases
  )
  func testBuild(target: String) async throws {
    try await run {
      $0.fileClient.fileExists = { _ in true }
    } operation: {
      @Dependency(\.cliClient) var client
      let output = try await client.build(.testOptions(
        target: target,
        versionStrategy: .semvar(requireExistingFile: false)
      ))
      #expect(output == "/baz/Sources/bar/Version.swift")
    }
  }

  @Test(
    arguments: TestArguments.bumpCases
  )
  func bump(type: CliClient.BumpOption, optional: Bool) async throws {
    let template = optional ? Template.optional("1.0.0-4-g59bc977") : Template.build("1.0.0")
    try await run {
      $0.fileClient.fileExists = { _ in true }
      $0.fileClient.read = { @Sendable _ in template }
    } operation: {
      @Dependency(\.cliClient) var client
      let output = try await client.bump(type, .testOptions())
      #expect(output == "/baz/Sources/bar/Version.swift")
    } assert: { string, _ in

      if type != .preRelease {
        #expect(string != nil)
      }
      let typeString = optional ? "String?" : "String"

      switch type {
      case .major:
        #expect(string!.contains("let VERSION: \(typeString) = \"2.0.0\""))
      case .minor:
        #expect(string!.contains("let VERSION: \(typeString) = \"1.1.0\""))
      case .patch:
        #expect(string!.contains("let VERSION: \(typeString) = \"1.0.1\""))
      case .preRelease:
        // do something
        #expect(Bool(true))
      }
    }
  }

  @Test(
    arguments: TestArguments.testCases
  )
  func generate(target: String) async throws {
    try await run {
      @Dependency(\.cliClient) var client
      let output = try await client.build(.testOptions(
        target: target,
        versionStrategy: .semvar(requireExistingFile: false)
      ))
      #expect(output == "/baz/Sources/bar/Version.swift")
    }
  }

  @Test(arguments: GitClient.Version.mocks)
  func gitVersionToSemVar(version: GitClient.Version) {
    let semVar = version.semVar
    if semVar != nil {
      #expect(semVar!.versionString(withPreReleaseTag: false) == "1.0.0")
      #expect(semVar!.versionString(withPreReleaseTag: true) == version.description)
    } else {
      let semVar = SemVar(preRelease: version.description)
      #expect(semVar.versionString(withPreReleaseTag: true) == "0.0.0-\(version.description)")
    }
  }

  func run(
    setupDependencies: @escaping (inout DependencyValues) -> Void = { _ in },
    operation: @Sendable @escaping () async throws -> Void,
    assert: @escaping (String?, URL?) -> Void = { _, _ in }
  ) async throws {
    let captured = CapturingWrite()

    try await withDependencies {
      $0.logger.logLevel = .debug
      $0.fileClient = .capturing(captured)
      $0.fileClient.fileExists = { _ in false }
      $0.gitClient = .mock(.tag("1.0.0"))
      $0.cliClient = .liveValue
      $0.configurationClient = .liveValue
      $0.configurationClient.find = { _ in URL(filePath: "/") }
      setupDependencies(&$0)
    } operation: {
      try await operation()
    }
    let data = await captured.data
    let url = await captured.url
    var string: String?

    if let data {
      string = String(bytes: data, encoding: .utf8)
    }

    assert(string, url)
  }
}

enum TestArguments {
  static let testCases = ["bar", "Sources/bar", "./Sources/bar"]
  static let bumpCases = CliClient.BumpOption.allCases.reduce(into: [(CliClient.BumpOption, Bool)]()) {
    $0.append(($1, true))
    $0.append(($1, false))
  }

  static let updateCases = testCases.map { ($0, Bool.random()) }
}

struct TestError: Error {}

extension CliClient.SharedOptions {
  static func testOptions(
    gitDirectory: String? = "/baz",
    dryRun: Bool = false,
    target: String = "bar",
    versionStrategy: Configuration.VersionStrategy = .semvar(.init())
  ) -> Self {
    return .init(
      dryRun: dryRun,
      projectDirectory: gitDirectory,
      loggingOptions: .init(command: "test", verbose: 2),
      configurationToMerge: .init(
        target: .init(module: .init(target)),
        strategy: versionStrategy
      )
    )
  }
}
