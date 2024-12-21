@_spi(Internal) import CliVersion
import Dependencies
import Foundation
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
      @Dependency(\.cliClient) var client
      let output = try await client.build(.testOptions(target: target))
      #expect(output == "/baz/Sources/bar/foo")
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
      #expect(output == "/baz/Sources/bar/foo")
    } assert: { string, _ in

      #expect(string != nil)
      let typeString = optional ? "String?" : "String"

      switch type {
      case .major:
        #expect(string!.contains("let VERSION: \(typeString) = \"2.0.0\""))
      case .minor:
        #expect(string!.contains("let VERSION: \(typeString) = \"1.1.0\""))
      case .patch:
        #expect(string!.contains("let VERSION: \(typeString) = \"1.0.1\""))
      }
    }
  }

  @Test(
    arguments: TestArguments.testCases
  )
  func generate(target: String) async throws {
    try await run {
      @Dependency(\.cliClient) var client
      let output = try await client.generate(.testOptions(target: target))
      #expect(output == "/baz/Sources/bar/foo")
    }
  }

  @Test(
    arguments: TestArguments.updateCases
  )
  func update(target: String, dryRun: Bool) async throws {
    try await run {
      $0.fileClient.fileExists = { _ in false }
    } operation: {
      @Dependency(\.cliClient) var client
      let output = try await client.update(.testOptions(dryRun: dryRun, target: target))
      #expect(output == "/baz/Sources/bar/foo")
    } assert: { string, _ in
      if dryRun {
        #expect(string == nil)
      }
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
      $0.gitVersionClient = .init { _, _ in "1.0.0" }
      $0.cliClient = .liveValue
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
  static let testCases = ["bar", "Sources/bar", "/Sources/bar", "./Sources/bar"]
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
    fileName: String = "foo",
    target: String = "bar",
    logLevel: Logger.Level = .trace
  ) -> Self {
    .init(
      gitDirectory: gitDirectory,
      dryRun: dryRun,
      fileName: fileName,
      target: target,
      logLevel: logLevel
    )
  }
}
