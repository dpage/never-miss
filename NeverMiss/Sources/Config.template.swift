import Foundation

struct Config {
    // IMPORTANT: Copy this file to Config.swift and replace with your own Google OAuth credentials
    // Get them from: https://console.cloud.google.com/
    // DO NOT commit Config.swift - it contains your secrets!

    static let googleClientID = "YOUR_CLIENT_ID.apps.googleusercontent.com"

    // Client secret - required for "Web application" type OAuth credentials
    // Leave empty if using "iOS" type credentials (recommended for security)
    static let googleClientSecret = "YOUR_CLIENT_SECRET_OR_EMPTY"

    // The redirect URI uses the REVERSED client ID as the URL scheme
    // This is required by Google for iOS/macOS OAuth
    static var googleRedirectURI: String {
        return "\(reversedClientID):/oauth2callback"
    }

    // Reversed client ID (used as URL scheme for OAuth callback)
    static var reversedClientID: String {
        // Reverse the client ID: xxx.apps.googleusercontent.com -> com.googleusercontent.apps.xxx
        let parts = googleClientID.components(separatedBy: ".")
        return parts.reversed().joined(separator: ".")
    }

    // OAuth scopes for Google Calendar
    static let googleScopes = [
        "https://www.googleapis.com/auth/calendar.readonly",
        "https://www.googleapis.com/auth/calendar.events.readonly",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile"
    ]

    // Google OAuth endpoints
    static let googleAuthURL = "https://accounts.google.com/o/oauth2/v2/auth"
    static let googleTokenURL = "https://oauth2.googleapis.com/token"
    static let googleUserInfoURL = "https://www.googleapis.com/oauth2/v2/userinfo"
    static let googleCalendarBaseURL = "https://www.googleapis.com/calendar/v3"

    // App bundle identifier
    static let bundleIdentifier = "org.pgadmin.nevermiss"
}
