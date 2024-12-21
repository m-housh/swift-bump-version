import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Logging

@_spi(Internal)
public extension Logger.Level {

  init(verbose: Int) {
    switch verbose {
    case 1: self = .warning
    case 2: self = .debug
    case 3...: self = .trace
    default: self = .info
    }
  }
}

@_spi(Internal)
public extension URL {
  var cleanFilePath: String {
    absoluteString.replacingOccurrences(of: "file://", with: "")
  }
}

// MARK: - Private

@_spi(Internal)
public func url(for path: String) -> URL {
  #if os(Linux)
    return URL(fileURLWithPath: path)
  #else
    if #available(macOS 13.0, *) {
      return URL(filePath: path)
    } else {
      // Fallback on earlier versions
      return URL(fileURLWithPath: path)
    }
  #endif
}
