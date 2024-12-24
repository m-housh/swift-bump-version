import ArgumentParser
import Foundation

@main
struct Application: AsyncParsableCommand {
  static let configuration: CommandConfiguration = .init(
    commandName: "bump-version",
    version: VERSION ?? "0.0.0",
    subcommands: [
      BuildCommand.self,
      BumpCommand.self,
      GenerateCommand.self,
      UtilsCommand.self
    ],
    defaultSubcommand: BumpCommand.self
  )
}
