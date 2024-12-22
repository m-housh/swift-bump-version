import Dependencies
import DependenciesMacros
import Foundation

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

  /// Return the current working directory.
  public var currentDirectory: @Sendable () async throws -> String

  /// Check if a file exists at the given url.
  public var fileExists: @Sendable (URL) -> Bool = { _ in true }

  /// Check if a url is a directory.
  public var isDirectory: @Sendable (String) async throws -> Bool

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
    currentDirectory: { "./" },
    fileExists: { _ in true },
    isDirectory: { _ in true },
    read: { _ in "" },
    write: { _, _ in }
  )

  /// An `unimplemented` ``FileClient``.
  public static let testValue = FileClient()

  /// The live ``FileClient``
  public static let liveValue = FileClient(
    currentDirectory: { FileManager.default.currentDirectoryPath },
    fileExists: { FileManager.default.fileExists(atPath: $0.cleanFilePath) },
    isDirectory: { path in
      var isDirectory: ObjCBool = false
      FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
      return isDirectory.boolValue
    },
    read: { try String(contentsOf: $0, encoding: .utf8) },
    write: { try $0.write(to: $1, options: .atomic) }
  )

  public static func capturing(
    _ captured: CapturingWrite
  ) -> Self {
    .init(
      currentDirectory: { "./" },
      fileExists: { _ in true },
      isDirectory: { _ in true },
      read: { _ in "" },
      write: { await captured.set($0, $1) }
    )
  }

}

public actor CapturingWrite: Sendable {
  public private(set) var data: Data?
  public private(set) var url: URL?

  public init() {}

  func set(_ data: Data, _ url: URL) {
    self.data = data
    self.url = url
  }
}

public extension URL {
  var cleanFilePath: String {
    absoluteString.replacingOccurrences(of: "file://", with: "")
  }
}

public func url(for path: String) -> URL {
  #if os(Linux)
    return URL(fileURLWithPath: path)
  #else
    if #available(macOS 13.0, *) {
      return URL(filePath: path)
    } else {
      // Fallback on earlier versions
      return URL(fileURLWithPath: path)
    }
  #endif
}
