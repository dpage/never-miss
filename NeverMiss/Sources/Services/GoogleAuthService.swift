import Foundation
import AuthenticationServices
import AppKit

class GoogleAuthService: NSObject {
    private var authSession: ASWebAuthenticationSession?
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - OAuth Flow

    func authenticate() async throws -> GoogleAccount {
        // Generate PKCE code verifier and challenge
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Build authorization URL
        let authURL = buildAuthorizationURL(codeChallenge: codeChallenge)

        // Perform OAuth flow
        let callbackURL = try await performOAuthFlow(authURL: authURL)

        // Extract authorization code from callback
        guard let code = extractAuthorizationCode(from: callbackURL) else {
            throw AuthError.invalidCallback
        }

        // Exchange code for tokens
        let tokens = try await exchangeCodeForTokens(code: code, codeVerifier: codeVerifier)

        // Fetch user info
        let userInfo = try await fetchUserInfo(accessToken: tokens.accessToken)

        // Create account
        var account = GoogleAccount(email: userInfo.email, displayName: userInfo.name)
        account.accessToken = tokens.accessToken
        account.refreshToken = tokens.refreshToken
        account.tokenExpiry = tokens.expiry

        return account
    }

    func refreshAccessToken(for account: GoogleAccount) async throws -> GoogleAccount {
        guard let refreshToken = account.refreshToken else {
            throw AuthError.noRefreshToken
        }

        let url = URL(string: Config.googleTokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var body = [
            "client_id": Config.googleClientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        // Add client_secret if configured
        if !Config.googleClientSecret.isEmpty && !Config.googleClientSecret.contains("YOUR_CLIENT_SECRET") {
            body["client_secret"] = Config.googleClientSecret
        }

        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
            // Refresh token is invalid, need to re-authenticate
            throw AuthError.refreshTokenRevoked
        }

        guard httpResponse.statusCode == 200 else {
            throw AuthError.tokenRefreshFailed
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Int else {
            throw AuthError.invalidTokenResponse
        }

        var updatedAccount = account
        updatedAccount.accessToken = accessToken
        updatedAccount.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))

        // If a new refresh token was provided, update it
        if let newRefreshToken = json["refresh_token"] as? String {
            updatedAccount.refreshToken = newRefreshToken
        }

        return updatedAccount
    }

    // MARK: - Private Methods

    private func buildAuthorizationURL(codeChallenge: String) -> URL {
        var components = URLComponents(string: Config.googleAuthURL)!

        components.queryItems = [
            URLQueryItem(name: "client_id", value: Config.googleClientID),
            URLQueryItem(name: "redirect_uri", value: Config.googleRedirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Config.googleScopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        return components.url!
    }

    private func performOAuthFlow(authURL: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                self?.authSession = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: Config.reversedClientID
                ) { callbackURL, error in
                    if let error = error {
                        if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                            continuation.resume(throwing: AuthError.userCancelled)
                        } else {
                            continuation.resume(throwing: AuthError.authSessionFailed(error))
                        }
                        return
                    }

                    guard let callbackURL = callbackURL else {
                        continuation.resume(throwing: AuthError.noCallback)
                        return
                    }

                    continuation.resume(returning: callbackURL)
                }

                self?.authSession?.presentationContextProvider = self
                self?.authSession?.prefersEphemeralWebBrowserSession = false
                self?.authSession?.start()
            }
        }
    }

    private func extractAuthorizationCode(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first { $0.name == "code" }?.value
    }

    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> TokenResponse {
        let url = URL(string: Config.googleTokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var body = [
            "client_id": Config.googleClientID,
            "code": code,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "redirect_uri": Config.googleRedirectURI
        ]

        // Add client_secret if configured (required for "Web application" type credentials)
        if !Config.googleClientSecret.isEmpty && !Config.googleClientSecret.contains("YOUR_CLIENT_SECRET") {
            body["client_secret"] = Config.googleClientSecret
        }

        print("[NeverMiss] Token exchange - redirect_uri: \(Config.googleRedirectURI)")
        print("[NeverMiss] Token exchange - client_id: \(Config.googleClientID)")

        // Use a restricted character set for form URL encoding (RFC 3986)
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-._~")

        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
            print("[NeverMiss] Token exchange body: \(bodyString)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        print("[NeverMiss] Token exchange response status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[NeverMiss] Token exchange response: \(responseString)")
        }

        guard httpResponse.statusCode == 200 else {
            throw AuthError.tokenExchangeFailed
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let refreshToken = json["refresh_token"] as? String,
              let expiresIn = json["expires_in"] as? Int else {
            throw AuthError.invalidTokenResponse
        }

        return TokenResponse(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiry: Date().addingTimeInterval(TimeInterval(expiresIn))
        )
    }

    private func fetchUserInfo(accessToken: String) async throws -> UserInfo {
        let url = URL(string: Config.googleUserInfoURL)!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.userInfoFailed
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let email = json["email"] as? String else {
            throw AuthError.invalidUserInfoResponse
        }

        let name = json["name"] as? String ?? email

        return UserInfo(email: email, name: name)
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApp.windows.first ?? ASPresentationAnchor()
    }
}

// MARK: - Supporting Types

struct TokenResponse {
    let accessToken: String
    let refreshToken: String
    let expiry: Date
}

struct UserInfo {
    let email: String
    let name: String
}

enum AuthError: LocalizedError {
    case userCancelled
    case noCallback
    case invalidCallback
    case authSessionFailed(Error)
    case tokenExchangeFailed
    case invalidTokenResponse
    case userInfoFailed
    case invalidUserInfoResponse
    case noRefreshToken
    case refreshTokenRevoked
    case tokenRefreshFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Authentication was cancelled"
        case .noCallback:
            return "No callback received from Google"
        case .invalidCallback:
            return "Invalid callback from Google"
        case .authSessionFailed(let error):
            return "Authentication failed: \(error.localizedDescription)"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for tokens"
        case .invalidTokenResponse:
            return "Invalid token response from Google"
        case .userInfoFailed:
            return "Failed to fetch user information"
        case .invalidUserInfoResponse:
            return "Invalid user info response from Google"
        case .noRefreshToken:
            return "No refresh token available"
        case .refreshTokenRevoked:
            return "Refresh token has been revoked. Please re-authenticate."
        case .tokenRefreshFailed:
            return "Failed to refresh access token"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

// CommonCrypto import for SHA256
import CommonCrypto
