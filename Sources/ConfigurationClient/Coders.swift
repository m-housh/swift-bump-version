import Dependencies
import DependenciesMacros
import Foundation
import TOMLKit

public extension DependencyValues {
  var coders: Coders {
    get { self[Coders.self] }
    set { self[Coders.self] = newValue }
  }
}

@DependencyClient
public struct Coders: Sendable {
  public var jsonDecoder: @Sendable () -> JSONDecoder = { .init() }
  public var jsonEncoder: @Sendable () -> JSONEncoder = { .init() }
  public var tomlDecoder: @Sendable () -> TOMLDecoder = { .init() }
  public var tomlEncoder: @Sendable () -> TOMLEncoder = { .init() }
}

extension Coders: DependencyKey {
  public static var testValue: Coders {
    .init(
      jsonDecoder: { .init() },
      jsonEncoder: { defaultJsonEncoder },
      tomlDecoder: { .init() },
      tomlEncoder: { .init() }
    )
  }

  public static var liveValue: Coders { .testValue }

  private static let defaultJsonEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }()
}
