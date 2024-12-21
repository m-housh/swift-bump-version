@_spi(Internal) import CliVersion
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite("CliClientTests")
struct CliClientTests {

  @Test(
    arguments: TestArguments.testCases
  )
  func testBuild(target: String) async throws {
    try await run {
      let client = CliClient.liveValue

      let output = try await client.build(.init(
        gitDirectory: "/baz",
        dryRun: false,
        fileName: "foo",
        target: target,
        verbose: true
      ))

      #expect(output == "/baz/Sources/bar/foo")
    }
  }

  @Test(
    arguments: TestArguments.bumpCases
  )
  func bump(type: CliClient.BumpOption, optional: Bool) async throws {
    let template = optional ? Template.optional("1.0.0") : Template.build("1.0.0")
    try await run {
      $0.fileClient.read = { _ in template }
    } operation: {
      let client = CliClient.liveValue
      let output = try await client.bump(
        type,
        .init(
          gitDirectory: "/baz",
          dryRun: false,
          fileName: "foo",
          target: "bar",
          verbose: true
        )
      )

      #expect(output == "/baz/Sources/bar/foo")
    }
  }

  @Test(
    arguments: TestArguments.testCases
  )
  func generate(target: String) async throws {
    // let (stream, continuation) = AsyncStream<Data>.makeStream()
    try await run {
      let client = CliClient.liveValue
      let output = try await client.generate(.init(
        gitDirectory: "/baz",
        dryRun: false,
        fileName: "foo",
        target: target,
        verbose: true
      ))
      #expect(output == "/baz/Sources/bar/foo")
    }
  }

  @Test(
    arguments: TestArguments.testCases
  )
  func update(target: String) async throws {
    // let (stream, continuation) = AsyncStream<Data>.makeStream()
    try await run {
      let client = CliClient.liveValue
      let output = try await client.update(.init(
        gitDirectory: "/baz",
        dryRun: false,
        fileName: "foo",
        target: target,
        verbose: true
      ))
      #expect(output == "/baz/Sources/bar/foo")
    }
  }

  func run(
    setupDependencies: @escaping (inout DependencyValues) -> Void = { _ in },
    operation: @Sendable @escaping () async throws -> Void
  ) async throws {
    try await withDependencies {
      $0.logger.logLevel = .debug
      $0.fileClient = .noop
      $0.fileClient.fileExists = { _ in false }
      $0.gitVersionClient = .init { _ in "1.0.0" }
      setupDependencies(&$0)
    } operation: {
      try await operation()
    }
  }
}

enum TestArguments {
  static let testCases = ["bar", "Sources/bar", "/Sources/bar", "./Sources/bar"]
  static let bumpCases = CliClient.BumpOption.allCases.reduce(into: [(CliClient.BumpOption, Bool)]()) {
    $0.append(($1, true))
    $0.append(($1, false))
  }
}
