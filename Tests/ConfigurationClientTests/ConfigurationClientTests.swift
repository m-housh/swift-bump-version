@_spi(Internal) import ConfigurationClient
import CustomDump
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
          let configuration = Configuration.mock()

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
          let configuration = Configuration.mock()

          try await configurationClient.write(configuration, fileUrl)
          let loaded = try await configurationClient.findAndLoad(fileUrl)
          #expect(loaded == configuration)

          try FileManager.default.removeItem(at: fileUrl)
        }
      }
    }
  }

  @Test
  func mergingBranch() {
    let branch = Configuration.Branch(includeCommitSha: false)
    let branch2 = Configuration.Branch(includeCommitSha: true)
    let merged = branch.merging(branch2)
    #expect(merged == branch2)

    let merged2 = branch.merging(nil)
    #expect(merged2 == branch)
  }

  @Test
  func mergingSemvar() {
    let strategy1 = Configuration.VersionStrategy.semvar(.init())
    let other = Configuration.VersionStrategy.semvar(.init(
      allowPreRelease: true,
      preRelease: .init(prefix: "foo", strategy: .gitTag),
      requireExistingFile: false,
      requireExistingSemVar: false,
      strategy: .gitTag()
    ))
    let merged = strategy1.merging(other)
    #expect(merged == other)

    let otherMerged = other.merging(strategy1)
    #expect(otherMerged == other)
  }

  @Test
  func mergingTarget() {
    let config1 = Configuration(target: .init(path: "foo"))
    let config2 = Configuration(target: .init(module: .init("bar")))

    let merged = config1.merging(config2)
    #expect(merged.target! == .init(module: .init("bar")))

    let merged2 = merged.merging(config1)
    #expect(merged2.target! == .init(path: "foo"))

    let merged3 = merged2.merging(nil)
    #expect(merged3 == merged2)
  }

  @Test
  func mergingVersionStrategy() {
    let version = Configuration.VersionStrategy.semvar(.init())
    let version2 = Configuration.VersionStrategy.branch(.init())

    let merged = version.merging(version2)
    #expect(merged == version2)

    let merged2 = merged.merging(.branch(includeCommitSha: false))
    #expect(merged2.branch!.includeCommitSha == false)

    let merged3 = version2.merging(version)
    #expect(merged3 == version)
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
