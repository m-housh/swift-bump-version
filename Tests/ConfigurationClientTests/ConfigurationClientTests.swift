import ConfigurationClient
import Dependencies
import Foundation
import Testing
import TestSupport
import TOMLKit

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
      let file = ConfigurationFile(url: URL(filePath: "\(fileName).\(ext)"))
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

  @Test
  func writeAndLoad() async throws {
    try await withTemporaryDirectory { url in
      try await run {
        @Dependency(\.configurationClient) var configurationClient

        for ext in ["toml", "json"] {
          let fileUrl = url.appending(path: "test.\(ext)")
          let configuration = Configuration.mock
          let configurationFile = ConfigurationFile(url: fileUrl)!

          try await configurationClient.write(configuration, configurationFile)
          let loaded = try await configurationClient.load(configurationFile)
          #expect(loaded == configuration)

          let findAndLoaded = try await configurationClient.findAndLoad(configurationFile.url)
          #expect(findAndLoaded == configuration)

          try FileManager.default.removeItem(at: fileUrl)
        }
      }
    }
  }

  @Test
  func findAndLoad() async throws {
    try await withTemporaryDirectory { url in
      try await run {
        @Dependency(\.configurationClient) var configurationClient

        let shouldBeNil = try await configurationClient.find(url)
        #expect(shouldBeNil == nil)

        do {
          _ = try await configurationClient.findAndLoad(url)
          #expect(Bool(false))
        } catch {
          #expect(Bool(true))
        }

        for ext in ["toml", "json"] {
          let fileUrl = url.appending(path: ".bump-version.\(ext)")
          let configuration = Configuration.mock
          let configurationFile = ConfigurationFile(url: fileUrl)!

          try await configurationClient.write(configuration, configurationFile)
          let loaded = try await configurationClient.findAndLoad(url)
          #expect(loaded == configuration)

          try FileManager.default.removeItem(at: fileUrl)
        }
      }
    }
  }

  // @Test
  // func writeDefault() async throws {
  //   try await run {
  //     @Dependency(\.coders) var coders
  //     @Dependency(\.configurationClient) var configurationClient
  //
  //     // let configuration = Configuration.customPreRelease
  //     // try await configurationClient.write(configuration, .json(URL(filePath: ".bump-version.json")))
  //
  //     // let target = Configuration.Target2.path("foo")
  //     // let target = Configuration.Target2.gitTag
  //     // let target = Configuration.Target2.branch()
  //     let target = Configuration2.mock
  //
  //     let encoded = try coders.jsonEncoder().encode(target)
  //     let url = URL(filePath: ".bump-version.json")
  //     try encoded.write(to: url)
  //
  //     let data = try Data(contentsOf: url)
  //     let decoded = try coders.jsonDecoder().decode(Configuration2.self, from: data)
  //     print(decoded)
  //   }
  // }

  // @Test
  // func tomlPlayground() throws {
  //   let jsonEncoder = JSONEncoder()
  //   let encoder = TOMLEncoder()
  //   let decoder = TOMLDecoder()
  //
  //   enum TestType: Codable {
  //     case one
  //     case hello(Hello)
  //
  //     struct Hello: Codable {
  //       let value: String
  //     }
  //   }
  //
  //   struct TestContainer: Codable {
  //     let testType: TestType
  //   }
  //
  //   let sut = TestContainer(testType: .hello(.init(value: "world")))
  //   let encoded = try encoder.encode(sut)
  //   print(encoded)
  //   // let decoded = try decoder.decode(TestContainer.self, from: encoded)
  //   // #expect(decoded.testType == sut.testType)
  // }

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
