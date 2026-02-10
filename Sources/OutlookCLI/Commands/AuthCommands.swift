import ArgumentParser
import OutlookCore
import Foundation

struct AuthCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "auth",
        abstract: "Manage authentication and accounts",
        subcommands: [Login.self, Logout.self, Accounts.self, Switch.self, Status.self]
    )
}

// MARK: - Login

extension AuthCommand {
    struct Login: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Authenticate with Microsoft 365 using device code flow"
        )

        @Option(name: .long, help: "Azure tenant ID (default: 'common')")
        var tenant: String?

        @Option(name: .long, help: "Azure app client ID")
        var clientId: String?

        func run() async throws {
            let config = OutlookConfig(clientId: clientId, tenantId: tenant)

            guard !config.clientId.isEmpty else {
                print("Error: No client ID configured.")
                print("Set OUTLOOK_CLIENT_ID environment variable or use --client-id flag.")
                throw ExitCode.failure
            }

            let storage = FileTokenStorage()
            let tokenManager = TokenManager(config: config, storage: storage)

            print("Starting device code authentication...")
            print()

            let accountId = try await tokenManager.authenticate { userCode, verificationUri in
                print("To sign in, visit: \(verificationUri)")
                print("Enter code: \(userCode)")
                print()
                print("Waiting for authentication...")
            }

            let accountManager = AccountManager(storage: storage)
            try await accountManager.setDefaultAccount(accountId)

            print()
            print("Successfully authenticated as: \(accountId)")
        }
    }
}

// MARK: - Logout

extension AuthCommand {
    struct Logout: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove an authenticated account"
        )

        @Argument(help: "Email address of the account to remove")
        var email: String?

        func run() async throws {
            let storage = FileTokenStorage()
            let accountManager = AccountManager(storage: storage)

            let accountId: String
            if let email = email {
                accountId = email
            } else {
                accountId = try await accountManager.getDefaultAccount()
            }

            try await accountManager.removeAccount(accountId)
            print("Removed account: \(accountId)")
        }
    }
}

// MARK: - Accounts

extension AuthCommand {
    struct Accounts: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all authenticated accounts"
        )

        func run() async throws {
            let storage = FileTokenStorage()
            let accountManager = AccountManager(storage: storage)
            let accounts = try await accountManager.listAccounts()

            if accounts.isEmpty {
                print("No authenticated accounts. Run 'outlook auth login' to get started.")
                return
            }

            let defaultId = try? await accountManager.getDefaultAccount()

            print("Authenticated accounts:")
            print()
            for account in accounts {
                let marker = account.id == defaultId ? " (default)" : ""
                let name = account.displayName ?? ""
                print("  \(account.id)\(marker)")
                if !name.isEmpty {
                    print("    Name: \(name)")
                }
                if let email = account.email {
                    print("    Email: \(email)")
                }
            }
        }
    }
}

// MARK: - Switch

extension AuthCommand {
    struct Switch: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Switch the default account"
        )

        @Argument(help: "Email address of the account to switch to")
        var email: String

        func run() async throws {
            let storage = FileTokenStorage()
            let accountManager = AccountManager(storage: storage)
            try await accountManager.setDefaultAccount(email)
            print("Switched default account to: \(email)")
        }
    }
}

// MARK: - Status

extension AuthCommand {
    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show current authentication status"
        )

        func run() async throws {
            let storage = FileTokenStorage()
            let accountManager = AccountManager(storage: storage)

            let defaultId: String
            do {
                defaultId = try await accountManager.getDefaultAccount()
            } catch {
                print("Not authenticated. Run 'outlook auth login' to get started.")
                return
            }

            guard let info = try await accountManager.getAccountInfo(defaultId) else {
                print("Account \(defaultId) not found.")
                return
            }

            print("Current account: \(info.id)")
            if let name = info.displayName {
                print("Name:           \(name)")
            }
            if let email = info.email {
                print("Email:          \(email)")
            }
            print("Tenant:         \(info.tenantId)")

            // Check if token is available
            let hasRefresh = try await storage.loadRefreshToken(for: defaultId) != nil
            print("Auth status:    \(hasRefresh ? "Authenticated (refresh token available)" : "Token missing — run 'outlook auth login'")")
        }
    }
}
