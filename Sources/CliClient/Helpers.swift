import Logging

// TODO: Move.
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
