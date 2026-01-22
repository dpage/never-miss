import Foundation

// Using UserDefaults for token storage instead of Keychain
// This avoids the keychain permission prompts when the app isn't properly code-signed
// Note: For production with proper code signing, Keychain would be more secure

struct KeychainHelper {
    private static let tokenPrefix = "nevermiss.tokens."

    struct TokenData {
        var accessToken: String?
        var refreshToken: String?
        var expiry: Date?
    }

    // MARK: - Token Operations

    static func saveTokens(accessToken: String?, refreshToken: String?, expiry: Date?, for accountId: String) {
        let defaults = UserDefaults.standard

        if let accessToken = accessToken {
            defaults.set(accessToken, forKey: "\(tokenPrefix)\(accountId).accessToken")
        }
        if let refreshToken = refreshToken {
            defaults.set(refreshToken, forKey: "\(tokenPrefix)\(accountId).refreshToken")
        }
        if let expiry = expiry {
            defaults.set(expiry, forKey: "\(tokenPrefix)\(accountId).tokenExpiry")
        }

        defaults.synchronize()
    }

    static func loadTokens(for accountId: String) -> TokenData {
        let defaults = UserDefaults.standard

        let accessToken = defaults.string(forKey: "\(tokenPrefix)\(accountId).accessToken")
        let refreshToken = defaults.string(forKey: "\(tokenPrefix)\(accountId).refreshToken")
        let expiry = defaults.object(forKey: "\(tokenPrefix)\(accountId).tokenExpiry") as? Date

        return TokenData(accessToken: accessToken, refreshToken: refreshToken, expiry: expiry)
    }

    static func deleteTokens(for accountId: String) {
        let defaults = UserDefaults.standard

        defaults.removeObject(forKey: "\(tokenPrefix)\(accountId).accessToken")
        defaults.removeObject(forKey: "\(tokenPrefix)\(accountId).refreshToken")
        defaults.removeObject(forKey: "\(tokenPrefix)\(accountId).tokenExpiry")

        defaults.synchronize()
    }

    // MARK: - Utility

    static func deleteAllTokens() {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys

        for key in allKeys where key.hasPrefix(tokenPrefix) {
            defaults.removeObject(forKey: key)
        }

        defaults.synchronize()
    }
}
