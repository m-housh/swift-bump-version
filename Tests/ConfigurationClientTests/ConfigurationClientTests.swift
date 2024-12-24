import ConfigurationClient
import Dependencies
import Foundation
import Testing
import TestSupport

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
    }
  }

  @Test
  func writeAndLoad() async throws {
    try await withTemporaryDirectory { url in
      try await run {
        @Dependency(\.configurationClient) var configurationClient

        for ext in ["json"] {
          let fileUrl = url.appending(path: "test.\(ext)")
          let configuration = Configuration.mock

          try await configurationClient.write(configuration, fileUrl)
          let loaded = try await configurationClient.load(fileUrl)
          #expect(loaded == configuration)

          let findAndLoaded = try await configurationClient.findAndLoad(fileUrl)
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

        for ext in ["json"] {
          let fileUrl = url.appending(path: ".bump-version.\(ext)")
          let configuration = Configuration.mock

          try await configurationClient.write(configuration, fileUrl)
          let loaded = try await configurationClient.findAndLoad(fileUrl)
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
