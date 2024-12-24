import Dependencies
import GitClient
import ShellClient
import Testing

@Suite("GitClientTests")
struct GitClientTests {

  @Test(arguments: GitClientVersionTestArgument.testCases)
  func testGitClient(input: GitClientVersionTestArgument) async throws {
    let arguments = try await run {
      @Dependency(\.gitClient) var gitClient
      _ = try await gitClient.version(.init(style: input.style))
    }
    #expect(arguments == input.expected)
  }

  func run(
    _ operation: () async throws -> Void
  ) async throws -> [[String]] {
    let captured = CapturedCommand()

    try await withDependencies {
      $0.asyncShellClient = .capturing(captured)
      $0.fileClient = .noop
      $0.gitClient = .liveValue
    } operation: {
      try await operation()
    }
    return await captured.commands.map(\.arguments)
  }
}

struct GitClientVersionTestArgument {
  let style: GitClient.CurrentVersionOption.Style
  let expected: [[String]]

  static let testCases: [Self] = [
    .init(
      style: .tag(exactMatch: true),
      expected: [["git", "describe", "--tags", "--exact-match"]]
    ),
    .init(
      style: .tag(exactMatch: false),
      expected: [["git", "describe", "--tags"]]
    ),
    .init(
      style: .branch(commitSha: false),
      expected: [["git", "symbolic-ref", "--quiet", "--short", "HEAD"]]
    ),
    .init(
      style: .branch(commitSha: true),
      expected: [
        ["git", "rev-parse", "--short", "HEAD"],
        ["git", "symbolic-ref", "--quiet", "--short", "HEAD"]
      ]
    )
  ]
}
