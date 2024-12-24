import ConfigurationClient
import Dependencies
import FileClient
import Foundation

extension Configuration {

  func mergingTarget(_ otherTarget: Configuration.Target?) -> Self {
    .init(
      target: otherTarget ?? target,
      strategy: strategy
    )
  }

  func mergingStrategy(_ otherStrategy: Configuration.VersionStrategy?) -> Self {
    .init(
      target: target,
      strategy: strategy?.merging(otherStrategy)
    )
  }
}

extension Configuration.Branch {
  func merging(_ other: Self?) -> Self {
    return .init(includeCommitSha: other?.includeCommitSha ?? includeCommitSha)
  }
}

extension Configuration.SemVar {
  func merging(_ other: Self?) -> Self {
    .init(
      preRelease: other?.preRelease ?? preRelease,
      requireExistingFile: other?.requireExistingFile ?? requireExistingFile,
      requireExistingSemVar: other?.requireExistingSemVar ?? requireExistingSemVar
    )
  }
}

extension Configuration.VersionStrategy {
  func merging(_ other: Self?) -> Self {
    guard let branch else {
      guard let semvar else { return self }
      return .semvar(semvar.merging(other?.semvar))
    }
    return .branch(branch.merging(other?.branch))
  }
}

@discardableResult
func withConfiguration<T>(
  path: String?,
  _ operation: (Configuration) async throws -> T
) async throws -> T {
  @Dependency(\.configurationClient) var configurationClient

  let configuration = try await configurationClient.findAndLoad(
    path != nil ? URL(filePath: path!) : nil
  )

  return try await operation(configuration)
}
