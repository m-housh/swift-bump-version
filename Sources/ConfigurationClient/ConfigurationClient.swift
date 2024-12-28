import Dependencies
import DependenciesMacros
import FileClient
import Foundation

// TODO: Add a method to get a semvar / handle a version strategy's ??

public extension DependencyValues {

  /// Perform operations with configuration files.
  var configurationClient: ConfigurationClient {
    get { self[ConfigurationClient.self] }
    set { self[ConfigurationClient.self] = newValue }
  }
}

/// Handles interactions with configuration files.
@DependencyClient
public struct ConfigurationClient: Sendable {

  fileprivate enum Constants {
    static let defaultFileNameWithoutExtension = ".bump-version"
    static let defaultExtension = "json"
    static var defaultFileName: String { "\(defaultFileNameWithoutExtension).\(defaultExtension)" }
  }

  /// The default file name for a configuration file.
  public var defaultFileName: @Sendable () -> String = { "test.json" }

  /// Find a configuration file in the given directory or in current working directory.
  public var find: @Sendable (URL?) async throws -> URL?

  /// Load a configuration file.
  public var load: @Sendable (URL) async throws -> Configuration

  /// Write a configuration file.
  public var write: @Sendable (Configuration, URL) async throws -> Void

  /// Find a configuration file and load it if found.
  ///
  /// - Parameters:
  ///   - url: The optional path to the configuration file.
  ///   - strict: Fail if a configuration file is not found, otherwise return default configuration.
  public func findAndLoad(_ url: URL? = nil, strict: Bool = true) async throws -> Configuration {
    guard let url = try? await find(url) else {
      if strict {
        throw ConfigurationClientError.configurationNotFound
      }
      return .default
    }

    let loaded = try? await load(url)
    guard let loaded else {
      if strict {
        throw ConfigurationClientError.configurationNotFound
      }
      return .default
    }
    return loaded
  }

  /// Loads configuration from the given path, or searches for the default file and loads it.
  /// Optionally merges other configuration, then perform an operation with the loaded configuration.
  ///
  /// - Parameters:
  ///   - path: Optional file path of the configuration to load.
  ///   - other: Optional configuration to merge with the loaded configuration.
  ///   - operation: The operation to perform with the loaded configuration.
  @discardableResult
  public func withConfiguration<T>(
    path: String?,
    merging other: Configuration? = nil,
    strict: Bool = true,
    operation: (Configuration) async throws -> T
  ) async throws -> T {
    let configuration = try await findAndLoad(
      path != nil ? URL(filePath: path!) : nil,
      strict: strict
    )
    return try await operation(configuration.merging(other))
  }
}

extension ConfigurationClient: DependencyKey {
  public static let testValue: ConfigurationClient = Self()

  public static var liveValue: ConfigurationClient {
    .init(
      defaultFileName: { "\(Constants.defaultFileNameWithoutExtension).json" },
      find: { try await findConfiguration($0) },
      load: { try await loadConfiguration($0) },
      write: { try await writeConfiguration($0, to: $1) }
    )
  }
}

private func findConfiguration(_ url: URL?) async throws -> URL? {
  @Dependency(\.fileClient) var fileClient

  var url: URL! = url
  if url == nil {
    url = try await URL(filePath: fileClient.currentDirectory())
  }

  if try await fileClient.isDirectory(url.cleanFilePath) {
    url = url.appending(path: ConfigurationClient.Constants.defaultFileName)
  }

  if fileClient.fileExists(url) {
    return url
  }
  return nil
}

private func loadConfiguration(_ url: URL) async throws -> Configuration {
  @Dependency(\.coders.jsonDecoder) var jsonDecoder
  @Dependency(\.fileClient) var fileClient

  let string = try await fileClient.read(url.cleanFilePath)
  return try jsonDecoder().decode(Configuration.self, from: Data(string.utf8))
}

enum ConfigurationClientError: Error {
  case configurationNotFound
  case invalidConfigurationDirectory(path: String)
}

private func writeConfiguration(_ configuration: Configuration, to url: URL) async throws {
  @Dependency(\.fileClient) var fileClient
  @Dependency(\.coders.jsonEncoder) var jsonEncoder
  let data = try jsonEncoder().encode(configuration)
  try await fileClient.write(data, url)
}
