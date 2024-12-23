import Dependencies
import FileClient
import Foundation

/// Represents a configuration file type and location.
public enum ConfigurationFile: Equatable, Sendable {

  /// A json configuration file.
  case json(URL)

  /// A toml configuration file.
  case toml(URL)

  /// Default configuration file, which is a toml file
  /// with the name of '.bump-version.toml'
  public static var `default`: Self {
    .toml(URL(
      filePath: "\(ConfigurationClient.Constants.defaultFileNameWithoutExtension).toml"
    ))
  }

  /// Create a new file location from the given url.
  ///
  /// - Parameters:
  ///   - url: The url for the file.
  public init?(url: URL) {
    if url.pathExtension == "toml" {
      self = .toml(url)
    } else if url.pathExtension == "json" {
      self = .json(url)
    } else {
      return nil
    }
  }

  /// The url of the file.
  public var url: URL {
    switch self {
    case let .json(url): return url
    case let .toml(url): return url
    }
  }
}

extension ConfigurationFile {

  func load() async throws -> Configuration? {
    @Dependency(\.coders) var coders
    @Dependency(\.fileClient) var fileClient

    switch self {
    case .json:
      let data = try await Data(fileClient.read(url.cleanFilePath).utf8)
      return try? coders.jsonDecoder().decode(Configuration.self, from: data)
    case .toml:
      let string = try await fileClient.read(url.cleanFilePath)
      return try? coders.tomlDecoder().decode(Configuration.self, from: string)
    }
  }

  func write(_ configuration: Configuration) async throws {
    @Dependency(\.coders) var coders
    @Dependency(\.fileClient) var fileClient

    let data: Data

    switch self {
    case .json:
      data = try coders.jsonEncoder().encode(configuration)
    case .toml:
      data = try Data(coders.tomlEncoder().encode(configuration).utf8)
    }

    try await fileClient.write(data, url)
  }
}
