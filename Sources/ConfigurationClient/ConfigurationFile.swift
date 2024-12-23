import Dependencies
import FileClient
import Foundation

public enum ConfigruationFile: Equatable, Sendable {
  case json(URL)
  case toml(URL)

  public init?(url: URL) {
    if url.pathExtension == "toml" {
      self = .toml(url)
    } else if url.pathExtension == "json" {
      self = .json(url)
    } else {
      return nil
    }
  }

  var url: URL {
    switch self {
    case let .json(url): return url
    case let .toml(url): return url
    }
  }
}

extension ConfigruationFile {

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
