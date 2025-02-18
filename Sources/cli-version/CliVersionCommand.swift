import ArgumentParser
import Foundation

@main
struct CliVersionCommand: ParsableCommand {
    static var configuration: CommandConfiguration = .init(
        commandName: "cli-version",
        version: VERSION ?? "0.0.0",
        subcommands: [
            Build.self,
            Generate.self,
            Update.self,
        ]
    )
}
