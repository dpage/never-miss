import Foundation

struct GoogleAccount: Identifiable, Codable {
    let id: String
    var email: String
    var displayName: String
    var isEnabled: Bool
    var accessToken: String?
    var refreshToken: String?
    var tokenExpiry: Date?

    var isTokenExpired: Bool {
        guard let expiry = tokenExpiry else { return true }
        return Date() >= expiry.addingTimeInterval(-60) // 1 minute buffer
    }

    var needsReauthentication: Bool {
        return refreshToken == nil || refreshToken?.isEmpty == true
    }

    init(id: String = UUID().uuidString, email: String, displayName: String = "") {
        self.id = id
        self.email = email
        self.displayName = displayName.isEmpty ? email : displayName
        self.isEnabled = true
    }

    // MARK: - Persistence

    private static let accountsKey = "nevermiss.accounts"

    static func loadAll() -> [GoogleAccount] {
        // Load account metadata from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: accountsKey),
              var accounts = try? JSONDecoder().decode([GoogleAccount].self, from: data) else {
            return []
        }

        // Load tokens from Keychain
        for i in accounts.indices {
            let tokens = KeychainHelper.loadTokens(for: accounts[i].id)
            accounts[i].accessToken = tokens.accessToken
            accounts[i].refreshToken = tokens.refreshToken
            accounts[i].tokenExpiry = tokens.expiry
        }

        return accounts
    }

    static func saveAll(_ accounts: [GoogleAccount]) {
        // Save account metadata to UserDefaults (without tokens)
        var accountsToSave = accounts
        for i in accountsToSave.indices {
            // Save tokens to Keychain
            KeychainHelper.saveTokens(
                accessToken: accounts[i].accessToken,
                refreshToken: accounts[i].refreshToken,
                expiry: accounts[i].tokenExpiry,
                for: accounts[i].id
            )

            // Clear tokens from the struct before saving to UserDefaults
            accountsToSave[i].accessToken = nil
            accountsToSave[i].refreshToken = nil
            accountsToSave[i].tokenExpiry = nil
        }

        if let data = try? JSONEncoder().encode(accountsToSave) {
            UserDefaults.standard.set(data, forKey: accountsKey)
            UserDefaults.standard.synchronize()
        }
    }

    static func delete(_ account: GoogleAccount) {
        KeychainHelper.deleteTokens(for: account.id)
        var accounts = loadAll()
        accounts.removeAll { $0.id == account.id }
        saveAll(accounts)
    }
}
