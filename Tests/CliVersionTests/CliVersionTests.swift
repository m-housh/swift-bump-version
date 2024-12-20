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
      $0.shellClient = .liveValue
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

  func test_overrides_work() throws {
    try withDependencies {
      $0.gitVersionClient.override(with: "blob")
    } operation: {
      @Dependency(\.gitVersionClient) var versionClient

      let version = try versionClient.currentVersion()
      XCTAssertEqual(version, "blob")
    }
  }

  func test_live() throws {
    @Dependency(\.gitVersionClient) var versionClient: GitVersionClient

    let version = try versionClient.currentVersion(in: gitDir)
    print("VERSION: \(version)")
    // can't really have a predictable result for the live client.
    XCTAssertNotEqual(version, "blob")
  }

  func test_commands() throws {
    @Dependency(\.shellClient) var shellClient: ShellClient

    XCTAssertNoThrow(
      try shellClient.background(
        .gitCurrentBranch(gitDirectory: gitDir),
        trimmingCharactersIn: .whitespacesAndNewlines
      )
    )

    XCTAssertNoThrow(
      try shellClient.background(
        .gitCurrentSha(gitDirectory: gitDir),
        trimmingCharactersIn: .whitespacesAndNewlines
      )
    )
  }

  func test_file_client() throws {
    try withTemporaryDirectory { tmpDir in
      @Dependency(\.fileClient) var fileClient

      let filePath = tmpDir.appendingPathComponent("blob.txt")
      try fileClient.write(string: "Blob", to: filePath)

      let contents = try fileClient.read(filePath)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      XCTAssertEqual(contents, "Blob")
    }
  }

  func test_file_client_with_string_path() throws {
    try withTemporaryDirectory { tmpDir in
      @Dependency(\.fileClient) var fileClient

      let filePath = tmpDir.appendingPathComponent("blob.txt")
      let fileString = filePath.cleanFilePath

      try fileClient.write(string: "Blob", to: fileString)

      let contents = try fileClient.read(fileString)
        .trimmingCharacters(in: .whitespacesAndNewlines)

      XCTAssertEqual(contents, "Blob")
    }
  }
}
