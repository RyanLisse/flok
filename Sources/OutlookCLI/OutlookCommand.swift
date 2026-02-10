import ArgumentParser

/// Root command for the OutlookCLI application.
public struct OutlookCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "outlook",
        abstract: "Microsoft 365 CLI — Mail, Calendar, Contacts, and OneDrive",
        version: "0.1.0",
        subcommands: [
            AuthCommand.self,
            MailCommand.self,
            CalCommand.self,
        ]
    )

    public init() {}
}
