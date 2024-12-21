@_spi(Internal) import CliVersion
import Dependencies
import ShellClient
import TestSupport
import XCTest

final class GitVersionTests: XCTestCase {

  override func invokeTest() {
    withDependencies({
      $0.logger.logLevel = .debug
      $0.logger = .liveValue
      $0.asyncShellClient = .liveValue
      $0.gitVersionClient = .liveValue
      $0.fileClient = .liveValue
    }, operation: {
      super.invokeTest()
    })
  }

  var gitDir: String {
    URL(fileURLWithPath: #file)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .cleanFilePath
  }

  func test_live() async throws {
    @Dependency(\.gitVersionClient) var versionClient: GitVersionClient

    let version = try await versionClient.currentVersion(in: gitDir)
    print("VERSION: \(version)")
    // can't really have a predictable result for the live client.
    XCTAssertNotEqual(version, "blob")
  }

  // func test_commands() throws {
  //   @Dependency(\.asyncShellClient) var shellClient: ShellClient
  //
  //   XCTAssertNoThrow(
  //     try shellClient.background(
  //       .gitCurrentBranch(gitDirectory: gitDir),
  //       trimmingCharactersIn: .whitespacesAndNewlines
  //     )
  //   )
  //
  //   XCTAssertNoThrow(
  //     try shellClient.background(
  //       .gitCurrentSha(gitDirectory: gitDir),
  //       trimmingCharactersIn: .whitespacesAndNewlines
  //     )
  //   )
  // }

  func test_file_client() async throws {
    try await withTemporaryDirectory { tmpDir in
      @Dependency(\.fileClient) var fileClient

      let filePath = tmpDir.appendingPathComponent("blob.txt")
      try await fileClient.write(string: "Blob", to: filePath)

      let contents = try await fileClient.read(filePath)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      XCTAssertEqual(contents, "Blob")
    }
  }

  func test_file_client_with_string_path() async throws {
    try await withTemporaryDirectory { tmpDir in
      @Dependency(\.fileClient) var fileClient

      let filePath = tmpDir.appendingPathComponent("blob.txt")
      let fileString = filePath.cleanFilePath

      try await fileClient.write(string: "Blob", to: fileString)

      let contents = try await fileClient.read(fileString)
        .trimmingCharacters(in: .whitespacesAndNewlines)

      XCTAssertEqual(contents, "Blob")
    }
  }
}
