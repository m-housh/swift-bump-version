import Logging

@_spi(Internal)
public extension Logger.Level {

  init(verbose: Int) {
    switch verbose {
    case 1: self = .debug
    case 2...: self = .trace
    default: self = .info
    }
  }
}
