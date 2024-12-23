import ArgumentParser
import Foundation

@main
struct CliVersionCommand: AsyncParsableCommand {
  static let configuration: CommandConfiguration = .init(
    commandName: "cli-version",
    version: VERSION ?? "0.0.0",
    subcommands: [
      Build.self,
      Bump.self,
      Generate.self
    ],
    defaultSubcommand: Bump.self
  )
}
