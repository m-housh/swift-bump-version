import Foundation

// swiftlint:disable force_try

/// Helper to create a temporary directory for running tests in.
///
/// The temporary directory will be removed after the operation has ran.
///
/// - Parameters:
///   - operation: The operation to run with the temporary directory.
public func withTemporaryDirectory(
  _ operation: (URL) throws -> Void
) rethrows {
  let tempUrl = FileManager.default
    .temporaryDirectory
    .appendingPathComponent(UUID().uuidString)

  try! FileManager.default.createDirectory(at: tempUrl, withIntermediateDirectories: false)
  try operation(tempUrl)
  try! FileManager.default.removeItem(at: tempUrl)
}

// swiftlint:enable force_try
