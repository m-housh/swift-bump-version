import ConfigurationClient

enum CliClientError: Error {
  case gitDirectoryNotFound
  case fileExists(path: String)
  case fileDoesNotExist(path: String)
  case failedToParseVersionFile
  case semVarNotFound(message: String)
  case strategyNotFound(configuration: Configuration)
  case preReleaseParsingError(String)
  case versionStringNotFound
}
