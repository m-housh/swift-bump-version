import Dependencies
import DependenciesMacros
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import XCTestDynamicOverlay

// TODO: This can be an internal dependency.

public extension DependencyValues {

  /// Access a basic ``FileClient`` that can read / write data to the file system.
  ///
  var fileClient: FileClient {
    get { self[FileClient.self] }
    set { self[FileClient.self] = newValue }
  }
}

/// Represents the interactions with the file system.  It is able
/// to read from and write to files.
///
///
/// ```swift
///  @Dependency(\.fileClient) var fileClient
/// ```
///
@DependencyClient
public struct FileClient: Sendable {

  /// Check if a file exists at the given url.
  public var fileExists: @Sendable (URL) -> Bool = { _ in true }

  /// Read the contents of a file.
  public var read: @Sendable (URL) async throws -> String

  /// Write `Data` to a file `URL`.
  public var write: @Sendable (Data, URL) async throws -> Void

  /// Read the contents of a file at the given path.
  ///
  /// - Parameters:
  ///   - path: The file path to read from.
  public func read(_ path: String) async throws -> String {
    try await read(url(for: path))
  }

  /// Write's the the string to a  file path.
  ///
  /// - Parameters:
  ///   - string: The string to write to the file.
  ///   - path: The file path.
  public func write(string: String, to path: String) async throws {
    try await write(string: string, to: url(for: path))
  }

  /// Write's the the string to a  file path.
  ///
  /// - Parameters:
  ///   - string: The string to write to the file.
  ///   - url: The file url.
  public func write(string: String, to url: URL) async throws {
    try await write(Data(string.utf8), url)
  }
}

extension FileClient: DependencyKey {

  /// A ``FileClient`` that does not do anything.
  public static let noop = FileClient(
    fileExists: { _ in true },
    read: { _ in "" },
    write: { _, _ in }
  )

  /// An `unimplemented` ``FileClient``.
  public static let testValue = FileClient()

  /// The live ``FileClient``
  public static let liveValue = FileClient(
    fileExists: { FileManager.default.fileExists(atPath: $0.cleanFilePath) },
    read: { try String(contentsOf: $0, encoding: .utf8) },
    write: { try $0.write(to: $1, options: .atomic) }
  )

  @_spi(Internal)
  public static func capturing(
    _ captured: CapturingWrite
  ) -> Self {
    .init(
      fileExists: { _ in true },
      read: { _ in "" },
      write: { await captured.set($0, $1) }
    )
  }

}

@_spi(Internal)
public actor CapturingWrite: Sendable {
  public private(set) var data: Data?
  public private(set) var url: URL?

  public init() {}

  func set(_ data: Data, _ url: URL) {
    self.data = data
    self.url = url
  }
}
