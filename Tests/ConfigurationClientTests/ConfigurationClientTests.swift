import ConfigurationClient
import Dependencies
import Foundation
import Testing

@Suite("ConfigurationClientTests")
struct ConfigurationClientTests {

  @Test
  func codable() async throws {
    try await run {
      @Dependency(\.configurationClient) var configurationClient
      @Dependency(\.coders) var coders

      let configuration = Configuration.customPreRelease
      let encoded = try coders.jsonEncoder().encode(configuration)
      let decoded = try coders.jsonDecoder().decode(Configuration.self, from: encoded)

      #expect(decoded == configuration)

      let tomlEncoded = try coders.tomlEncoder().encode(configuration)
      let tomlDecoded = try coders.tomlDecoder().decode(
        Configuration.self,
        from: tomlEncoded
      )
      #expect(tomlDecoded == configuration)
    }
  }

  @Test(arguments: ["foo", ".foo"])
  func configurationFile(fileName: String) {
    for ext in ["toml", "json", "bar"] {
      let file = ConfigruationFile(url: URL(filePath: "\(fileName).\(ext)"))
      switch ext {
      case "toml":
        #expect(file == .toml(URL(filePath: "\(fileName).toml")))
      case "json":
        #expect(file == .json(URL(filePath: "\(fileName).json")))
      default:
        #expect(file == nil)
      }
    }
  }

  func run(
    setupDependencies: @escaping (inout DependencyValues) -> Void = { _ in },
    operation: () async throws -> Void
  ) async throws {
    try await withDependencies {
      $0.coders = .liveValue
      $0.fileClient = .liveValue
      $0.configurationClient = .liveValue
      setupDependencies(&$0)
    } operation: {
      try await operation()
    }
  }
}
