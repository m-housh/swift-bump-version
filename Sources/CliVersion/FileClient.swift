import Dependencies
import DependenciesMacros
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import XCTestDynamicOverlay

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

  public var fileExists: @Sendable (URL) -> Bool = { _ in true }

  /// Read the contents of a file.
  public var read: @Sendable (URL) throws -> String

  /// Write `Data` to a file `URL`.
  public var write: @Sendable (Data, URL) throws -> Void

  /// Read the contents of a file at the given path.
  ///
  /// - Parameters:
  ///   - path: The file path to read from.
  public func read(_ path: String) throws -> String {
    try read(url(for: path))
  }

  /// Write's the the string to a  file path.
  ///
  /// - Parameters:
  ///   - string: The string to write to the file.
  ///   - path: The file path.
  public func write(string: String, to path: String) throws {
    let url = url(for: path)
    try write(string: string, to: url)
  }

  /// Write's the the string to a  file path.
  ///
  /// - Parameters:
  ///   - string: The string to write to the file.
  ///   - url: The file url.
  public func write(string: String, to url: URL) throws {
    try write(Data(string.utf8), url)
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

}
