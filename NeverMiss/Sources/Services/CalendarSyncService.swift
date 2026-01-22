import Foundation

class CalendarSyncService {
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    @MainActor
    private func createAuthService() -> GoogleAuthService? {
        guard let appState = appState else { return nil }
        return GoogleAuthService(appState: appState)
    }

    func syncAllAccounts() async {
        guard let appState = appState else { return }

        var allEvents: [CalendarEvent] = []
        var accountsToUpdate: [(Int, GoogleAccount)] = []

        for (index, account) in appState.accounts.enumerated() {
            guard account.isEnabled else { continue }

            do {
                var currentAccount = account

                // Refresh token if needed
                if currentAccount.isTokenExpired {
                    do {
                        currentAccount = try await refreshToken(for: currentAccount)
                        accountsToUpdate.append((index, currentAccount))
                    } catch AuthError.refreshTokenRevoked {
                        // Need to re-authenticate
                        await promptReauthentication(for: currentAccount)
                        continue
                    }
                }

                // Fetch events
                let calendarService = GoogleCalendarService(account: currentAccount)
                let events = try await calendarService.fetchUpcomingEvents()
                allEvents.append(contentsOf: events)

            } catch CalendarError.unauthorized {
                // Token is invalid, try refreshing
                do {
                    let refreshedAccount = try await refreshToken(for: account)
                    accountsToUpdate.append((index, refreshedAccount))

                    // Retry fetch
                    let calendarService = GoogleCalendarService(account: refreshedAccount)
                    let events = try await calendarService.fetchUpcomingEvents()
                    allEvents.append(contentsOf: events)
                } catch {
                    await promptReauthentication(for: account)
                }
            } catch {
                print("Error syncing account \(account.email): \(error.localizedDescription)")
            }
        }

        // Update accounts with refreshed tokens
        let finalAccountsToUpdate = accountsToUpdate
        let finalAllEvents = allEvents
        await MainActor.run {
            for (index, updatedAccount) in finalAccountsToUpdate {
                if index < appState.accounts.count {
                    appState.accounts[index] = updatedAccount
                }
            }
            appState.saveAccounts()

            // Update events
            appState.events = finalAllEvents
        }
    }

    private func refreshToken(for account: GoogleAccount) async throws -> GoogleAccount {
        guard let authService = await createAuthService() else {
            throw AuthError.invalidResponse
        }
        return try await authService.refreshAccessToken(for: account)
    }

    @MainActor
    private func promptReauthentication(for account: GoogleAccount) {
        guard let appState = appState else { return }

        // Show notification that re-authentication is needed
        let alert = NSAlert()
        alert.messageText = "Re-authentication Required"
        alert.informativeText = "Your Google account '\(account.email)' needs to be re-authenticated. Please sign in again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Sign In")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // Trigger re-authentication
            Task {
                appState.isAuthenticating = true
                do {
                    let authService = createAuthService()
                    let newAccount = try await authService?.authenticate()
                    if let newAccount = newAccount {
                        // Replace the old account
                        if let index = appState.accounts.firstIndex(where: { $0.id == account.id }) {
                            appState.accounts[index] = newAccount
                        } else {
                            appState.accounts.append(newAccount)
                        }
                        appState.saveAccounts()
                    }
                } catch {
                    print("Re-authentication failed: \(error.localizedDescription)")
                }
                appState.isAuthenticating = false
            }
        }
    }
}

import AppKit
