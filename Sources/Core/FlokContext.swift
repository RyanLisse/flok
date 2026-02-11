import Foundation

/// Shared context holding auth, Graph client, and domain services. Used by CLI and MCP.
public struct FlokContext: Sendable {
    public let config: FlokConfig
    public let tokenManager: TokenManager
    public let graphClient: GraphClient
    public let mailService: MailService
    public let calendarService: CalendarService
    public let contactService: ContactService
    public let driveService: DriveService

    public init(config: FlokConfig) {
        self.config = config
        self.tokenManager = TokenManager(
            clientId: config.clientId,
            tenantId: config.tenantId,
            account: config.account
        )
        self.graphClient = GraphClient(
            tokenProvider: tokenManager,
            apiVersion: config.apiVersion
        )
        self.mailService = MailService(client: graphClient)
        self.calendarService = CalendarService(client: graphClient)
        self.contactService = ContactService(client: graphClient)
        self.driveService = DriveService(client: graphClient)
    }
}
