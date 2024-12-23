enum CliClientError: Error {
  case gitDirectoryNotFound
  case fileExists(path: String)
  case fileDoesNotExist(path: String)
  case failedToParseVersionFile
  case semVarNotFound
}
