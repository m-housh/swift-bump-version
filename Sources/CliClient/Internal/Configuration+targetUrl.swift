import ConfigurationClient
import CustomDump
import Dependencies
import Foundation
import GitClient
import ShellClient

extension Configuration {
  func targetUrl(projectDirectory: String?) throws -> URL {
    guard let target else {
      throw ConfigurationParsingError.targetNotFound
    }
    return try target.url(projectDirectory: projectDirectory)
  }
}

private extension Configuration.Target {
  func url(projectDirectory: String?) throws -> URL {
    @Dependency(\.logger) var logger

    let filePath: String

    if let path {
      filePath = path
    } else {
      guard let module else {
        throw ConfigurationParsingError.pathOrModuleNotSet
      }

      var path = module.name
      logger.debug("module.name: \(path)")

      if path.hasPrefix("./") {
        path = String(path.dropFirst(2))
      }

      if !path.hasPrefix("Sources") {
        logger.debug("no prefix")
        path = "Sources/\(path)"
      }

      filePath = "\(path)/\(module.fileNameOrDefault)"
    }

    if let projectDirectory {
      return URL(filePath: "\(projectDirectory)/\(filePath)")
    }
    return URL(filePath: filePath)
  }
}

enum ConfigurationParsingError: Error {
  case targetNotFound
  case pathOrModuleNotSet
  case versionStrategyError(message: String)
  case versionStrategyNotFound
}
