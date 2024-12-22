import Foundation
import GitClient

// Container for sem-var version.
@_spi(Internal)
public struct SemVar: CustomStringConvertible, Equatable, Sendable {
  /// The major version.
  public let major: Int
  /// The minor version.
  public let minor: Int
  /// The patch version.
  public let patch: Int
  /// Extra pre-release tag.
  public let preRelease: String?

  public init(
    major: Int,
    minor: Int,
    patch: Int,
    preRelease: String? = nil
  ) {
    self.major = major
    self.minor = minor
    self.patch = patch
    self.preRelease = preRelease
  }

  public init(preRelease: String? = nil) {
    self.init(
      major: 0,
      minor: 0,
      patch: 0,
      preRelease: preRelease
    )
  }

  public init?(string: String) {
    let parts = string.split(separator: ".")
    guard parts.count >= 3 else {
      return nil
    }
    let major = Int(String(parts[0].replacingOccurrences(of: "\"", with: "")))
    let minor = Int(String(parts[1]))

    let patchParts = parts[2].split(separator: "-")
    let patch = Int(patchParts.first ?? "0")
    let preRelease = String(patchParts.dropFirst().joined(separator: "-"))

    self.init(
      major: major ?? 0,
      minor: minor ?? 0,
      patch: patch ?? 0,
      preRelease: preRelease
    )
  }

  public var description: String { versionString() }

  // Create a version string, optionally appending a suffix.
  public func versionString(withPreReleaseTag: Bool = true) -> String {
    let string = "\(major).\(minor).\(patch)"

    guard withPreReleaseTag else { return string }

    guard let suffix = preRelease, suffix.count > 0 else {
      return string
    }

    if !suffix.hasPrefix("-") {
      return "\(string)-\(suffix)"
    }

    return "\(string)\(suffix)"
  }

  // Bumps the sem-var by the given option (major, minor, patch)
  public func bump(_ option: CliClient.BumpOption) -> Self {
    switch option {
    case .major:
      return .init(
        major: major + 1,
        minor: 0,
        patch: 0,
        preRelease: preRelease
      )
    case .minor:
      return .init(
        major: major,
        minor: minor + 1,
        patch: 0,
        preRelease: preRelease
      )
    case .patch:
      return .init(
        major: major,
        minor: minor,
        patch: patch + 1,
        preRelease: preRelease
      )
    }
  }
}

@_spi(Internal)
public extension GitClient.Version {
  var semVar: SemVar? {
    .init(string: description)
  }
}
