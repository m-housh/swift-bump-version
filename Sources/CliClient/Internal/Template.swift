@_spi(Internal)
public struct Template: Sendable {
  let type: TemplateType
  let version: String?

  enum TemplateType: String, Sendable {
    case optionalString = "String?"
    case string = "String"
  }

  var value: String {
    let versionString = version != nil ? "\"\(version!)\"" : "nil"
    return """
    // Do not set this variable, it is set during the build process.
    let VERSION: \(type.rawValue) = \(versionString)
    """
  }

  public static func build(_ version: String? = nil) -> String {
    nonOptional(version)
  }

  public static func nonOptional(_ version: String? = nil) -> String {
    Self(type: .string, version: version).value
  }

  public static func optional(_ version: String? = nil) -> String {
    Self(type: .optionalString, version: version).value
  }
}
