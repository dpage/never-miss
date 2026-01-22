import SwiftUI

struct MenuDropdownView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Upcoming Meetings")
                    .font(.headline)
                Spacer()
                Button(action: {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }) {
                    Image(systemName: "gear")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if appState.accounts.isEmpty {
                // No accounts connected
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No accounts connected")
                        .font(.headline)
                    Text("Add a Google Calendar account to see your meetings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Add Account") {
                        addAccount()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            } else if appState.nextMeetings.isEmpty {
                // No upcoming meetings
                VStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No upcoming meetings")
                        .font(.headline)
                    Text("You're all clear for now")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            } else {
                // Meeting list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(appState.nextMeetings) { event in
                            MeetingRowView(event: event)
                            if event.id != appState.nextMeetings.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            Divider()

            // Footer actions
            HStack {
                if !appState.accounts.isEmpty {
                    Button(action: addAccount) {
                        Label("Add Account", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 360)
    }

    private func addAccount() {
        Task {
            await MainActor.run {
                appState.isAuthenticating = true
            }
            do {
                let authService = GoogleAuthService(appState: appState)
                let account = try await authService.authenticate()

                await MainActor.run {
                    // Check if account already exists
                    if let existingIndex = appState.accounts.firstIndex(where: { $0.email == account.email }) {
                        // Update existing account with new tokens
                        appState.accounts[existingIndex] = account
                    } else {
                        appState.accounts.append(account)
                    }
                    appState.saveAccounts()
                }

                // Trigger sync
                let syncService = CalendarSyncService(appState: appState)
                await syncService.syncAllAccounts()
            } catch AuthError.userCancelled {
                // User cancelled, do nothing
            } catch {
                print("Authentication failed: \(error.localizedDescription)")
            }
            await MainActor.run {
                appState.isAuthenticating = false
            }
        }
    }
}

struct MeetingRowView: View {
    let event: CalendarEvent

    private var isInProgress: Bool {
        let now = Date()
        return event.startTime <= now && event.endTime > now
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if isInProgress {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Spacer()

                if isInProgress {
                    Text("In progress")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                } else {
                    Text(TimeFormatting.relativeTime(to: event.startTime))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                if event.isAllDay {
                    Text("All day")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text(TimeFormatting.timeRange(start: event.startTime, end: event.endTime))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                if event.hasConferenceLink {
                    Spacer()
                    Button(action: {
                        joinMeeting()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: conferencIcon)
                            Text("Join")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            if let location = event.location, !location.isEmpty, !location.contains("http") {
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.system(size: 10))
                    Text(location)
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .lineLimit(1)
            }

            // Response status indicator
            if event.responseStatus != .accepted {
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            if let htmlLink = event.htmlLink, let url = URL(string: htmlLink) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private var conferencIcon: String {
        guard let info = event.conferenceInfo else { return "video" }
        switch info.provider {
        case .googleMeet: return "video"
        case .zoom: return "video.fill"
        case .teams: return "person.2.fill"
        case .webex: return "video.badge.checkmark"
        case .other: return "video"
        }
    }

    private var statusColor: Color {
        switch event.responseStatus {
        case .accepted: return .green
        case .tentative: return .yellow
        case .declined: return .red
        case .needsAction: return .gray
        }
    }

    private var statusText: String {
        switch event.responseStatus {
        case .accepted: return "Accepted"
        case .tentative: return "Tentative"
        case .declined: return "Declined"
        case .needsAction: return "Not responded"
        }
    }

    private func joinMeeting() {
        guard let joinUrl = event.conferenceInfo?.joinUrl,
              let url = URL(string: joinUrl) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}

#Preview {
    MenuDropdownView()
        .environmentObject(AppState())
}
