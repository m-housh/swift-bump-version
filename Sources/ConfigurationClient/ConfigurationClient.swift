import Dependencies
import DependenciesMacros
import FileClient
import Foundation

public extension DependencyValues {
  var configurationClient: ConfigurationClient {
    get { self[ConfigurationClient.self] }
    set { self[ConfigurationClient.self] = newValue }
  }
}

@DependencyClient
public struct ConfigurationClient: Sendable {
  public var find: @Sendable (URL?) async throws -> ConfigruationFile?
  public var load: @Sendable (ConfigruationFile) async throws -> Configuration
  public var write: @Sendable (Configuration, ConfigruationFile) async throws -> Void

  public func findAndLoad(_ url: URL? = nil) async throws -> Configuration {
    guard let url = try await find(url) else {
      throw ConfigurationClientError.configurationNotFound
    }
    return try await load(url)
  }
}

extension ConfigurationClient: DependencyKey {
  public static let testValue: ConfigurationClient = Self()

  public static var liveValue: ConfigurationClient {
    .init(
      find: { try await findConfiguration($0) },
      load: { try await $0.load() ?? .init() },
      write: { try await $1.write($0) }
    )
  }
}

private func findConfiguration(_ url: URL?) async throws -> ConfigruationFile? {
  @Dependency(\.fileClient) var fileClient

  var url: URL! = url
  if url == nil {
    url = try await URL(filePath: fileClient.currentDirectory())
  }

  // Check if url is a valid configuration url.
  var configurationFile = ConfigruationFile(url: url)
  if let configurationFile { return configurationFile }

  guard try await fileClient.isDirectory(url.cleanFilePath) else {
    throw ConfigurationClientError.invalidConfigurationDirectory(path: url.cleanFilePath)
  }

  // Check for toml file.
  let tomlUrl = url.appending(path: "\(ConfigurationClient.Constants.defaultFileNameWithoutExtension).toml")
  configurationFile = ConfigruationFile(url: tomlUrl)
  if let configurationFile { return configurationFile }

  // Check for json file.
  let jsonUrl = url.appending(path: "\(ConfigurationClient.Constants.defaultFileNameWithoutExtension).json")
  configurationFile = ConfigruationFile(url: jsonUrl)
  if let configurationFile { return configurationFile }

  // Couldn't find valid configuration file.
  return nil
}

enum ConfigurationClientError: Error {
  case configurationNotFound
  case invalidConfigurationDirectory(path: String)
}
