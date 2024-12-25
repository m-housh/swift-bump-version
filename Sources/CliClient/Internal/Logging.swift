import Dependencies
import Foundation
import Logging
import LoggingFormatAndPipe
import Rainbow
import ShellClient

extension String {
  var orange: Self {
    bit24(255, 165, 0)
  }

  var magena: Self {
    // bit24(186, 85, 211)
    bit24(238, 130, 238)
  }
}

@_spi(Internal)
public extension Logger.Level {

  init(verbose: Int) {
    switch verbose {
    case 1: self = .debug
    case 2...: self = .trace
    default: self = .warning
    }
  }

  var coloredString: String {
    switch self {
    case .info:
      return "\(self)".cyan
    case .warning:
      return "\(self)".orange.bold
    case .debug:
      return "\(self)".green
    case .trace:
      return "\(self)".yellow
    case .error:
      return "\(self)".red.bold
    default:
      return "\(self)"
    }
  }
}

struct LevelFormatter: LoggingFormatAndPipe.Formatter {

  let basic: BasicFormatter

  var timestampFormatter: DateFormatter { basic.timestampFormatter }

  // swiftlint:disable function_parameter_count
  func processLog(
    level: Logger.Level,
    message: Logger.Message,
    prettyMetadata: String?,
    file: String,
    function: String,
    line: UInt
  ) -> String {
    let now = Date()

    return basic.format.map { component -> String in
      return processComponent(
        component,
        now: now,
        level: level,
        message: message,
        prettyMetadata: prettyMetadata,
        file: file,
        function: function,
        line: line
      )
    }
    .filter { $0.count > 0 }
    .joined(separator: basic.separator ?? "")
  }

  public func processComponent(
    _ component: LogComponent,
    now: Date,
    level: Logger.Level,
    message: Logger.Message,
    prettyMetadata: String?,
    file: String,
    function: String,
    line: UInt
  ) -> String {
    switch component {
    case .level:
      let maxLen = "\(Logger.Level.warning)".count
      let paddingCount = (maxLen - "\(level)".count) / 2
      var padding = ""
      for _ in 0 ... paddingCount {
        padding += " "
      }
      return "\(padding)\(level.coloredString)\(padding)"
    case let .group(components):
      return components.map { component -> String in
        self.processComponent(
          component,
          now: now,
          level: level,
          message: message,
          prettyMetadata: prettyMetadata,
          file: file,
          function: function,
          line: line
        )
      }.joined()
    case .message:
      return basic.processComponent(
        component,
        now: now,
        level: level,
        message: message,
        prettyMetadata: prettyMetadata,
        file: file,
        function: function,
        line: line
      ).italic
    default:
      return basic.processComponent(
        component,
        now: now,
        level: level,
        message: message,
        prettyMetadata: prettyMetadata,
        file: file,
        function: function,
        line: line
      )
    }
  }
  // swiftlint:enable function_parameter_count

}

extension CliClient.LoggingOptions {

  func makeLogger() -> Logger {
    let formatters: [LogComponent] = [
      .text(executableName.magena),
      .text(command.blue),
      .level,
      .group([
        .text("-> "),
        .message
      ])
    ]
    return Logger(label: executableName) { _ in
      LoggingFormatAndPipe.Handler(
        formatter: LevelFormatter(basic: BasicFormatter(
          formatters,
          separator: " | "
        )),
        pipe: LoggerTextOutputStreamPipe.standardOutput
      )
    }
  }

  func withLogger<T>(_ operation: () async throws -> T) async rethrows -> T {
    try await withDependencies {
      $0.logger = makeLogger()
      $0.logger.logLevel = .init(verbose: verbose)
    } operation: {
      try await operation()
    }
  }
}
