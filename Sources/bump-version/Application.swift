import ArgumentParser
import Foundation

@main
struct Application: AsyncParsableCommand {
  static let commandName = "bump-version"

  static let configuration: CommandConfiguration = .init(
    commandName: commandName,
    version: VERSION ?? "0.0.0",
    subcommands: [
      BuildCommand.self,
      BumpCommand.self,
      GenerateCommand.self,
      ConfigCommand.self
    ],
    defaultSubcommand: BumpCommand.self
  )
}
