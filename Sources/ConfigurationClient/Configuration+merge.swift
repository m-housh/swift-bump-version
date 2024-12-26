import Dependencies
import FileClient
import Foundation

@_spi(Internal)
public extension Configuration {

  func merging(_ other: Self?) -> Self {
    mergingTarget(other?.target).mergingStrategy(other?.strategy)
  }

  private func mergingTarget(_ otherTarget: Configuration.Target?) -> Self {
    .init(
      target: otherTarget ?? target,
      strategy: strategy
    )
  }

  private func mergingStrategy(_ otherStrategy: Configuration.VersionStrategy?) -> Self {
    .init(
      target: target,
      strategy: strategy?.merging(otherStrategy)
    )
  }
}

@_spi(Internal)
public extension Configuration.PreRelease {
  func merging(_ other: Self?) -> Self {
    return .init(
      prefix: other?.prefix ?? prefix,
      strategy: other?.strategy ?? strategy
    )
  }
}

@_spi(Internal)
public extension Configuration.Branch {
  func merging(_ other: Self?) -> Self {
    return .init(includeCommitSha: other?.includeCommitSha ?? includeCommitSha)
  }
}

@_spi(Internal)
public extension Configuration.SemVar {
  func merging(_ other: Self?) -> Self {
    .init(
      allowPreRelease: other?.allowPreRelease ?? allowPreRelease,
      preRelease: preRelease == nil ? other?.preRelease : preRelease!.merging(other?.preRelease),
      requireExistingFile: other?.requireExistingFile ?? requireExistingFile,
      requireExistingSemVar: other?.requireExistingSemVar ?? requireExistingSemVar,
      strategy: other?.strategy ?? strategy
    )
  }
}

@_spi(Internal)
public extension Configuration.VersionStrategy {
  func merging(_ other: Self?) -> Self {
    guard let other else { return self }

    switch other {
    case .branch:
      guard let branch else { return other }
      return .branch(branch.merging(other.branch))
    case .semvar:
      guard let semvar else { return other }
      return .semvar(semvar.merging(other.semvar))
    }
  }
}
