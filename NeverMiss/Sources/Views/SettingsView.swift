import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AccountsSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("Accounts", systemImage: "person.2")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 350)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var settings: AppSettings = AppSettings.load()

    var body: some View {
        Form {
            Section {
                Picker("Refresh calendar data", selection: $settings.refreshInterval) {
                    ForEach(AppSettings.refreshIntervalOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }

                Picker("Show popup notification", selection: $settings.notificationLeadTime) {
                    ForEach(AppSettings.notificationLeadTimeOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }
            } header: {
                Text("Timing")
            }

            Section {
                Toggle("Show popup notifications", isOn: $settings.showPopupNotifications)
                Toggle("Play sound with notifications", isOn: $settings.playSound)
                    .disabled(!settings.showPopupNotifications)
                Toggle("Only show accepted meetings", isOn: $settings.showOnlyAccepted)
            } header: {
                Text("Notifications")
            }

            Section {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            } header: {
                Text("System")
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings) { newSettings in
            newSettings.save()
            appState.settings = newSettings
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
}

struct AccountsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isAuthenticating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.accounts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No accounts connected")
                        .font(.headline)

                    Text("Connect your Google Calendar accounts to see your upcoming meetings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Add Google Account") {
                        addAccount()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAuthenticating)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(appState.accounts) { account in
                        AccountRowView(account: account) {
                            removeAccount(account)
                        } onToggle: { enabled in
                            toggleAccount(account, enabled: enabled)
                        }
                    }
                }

                Divider()

                HStack {
                    Button("Add Account") {
                        addAccount()
                    }
                    .disabled(isAuthenticating)

                    Spacer()

                    if isAuthenticating {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding()
            }
        }
    }

    private func addAccount() {
        isAuthenticating = true
        Task {
            do {
                let authService = GoogleAuthService(appState: appState)
                let account = try await authService.authenticate()

                await MainActor.run {
                    // Check if account already exists
                    if !appState.accounts.contains(where: { $0.email == account.email }) {
                        appState.accounts.append(account)
                        appState.saveAccounts()
                    }
                    isAuthenticating = false
                }

                // Trigger sync
                let syncService = CalendarSyncService(appState: appState)
                await syncService.syncAllAccounts()
            } catch AuthError.userCancelled {
                await MainActor.run {
                    isAuthenticating = false
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                }
                print("Authentication failed: \(error.localizedDescription)")
            }
        }
    }

    private func removeAccount(_ account: GoogleAccount) {
        GoogleAccount.delete(account)
        appState.accounts.removeAll { $0.id == account.id }
        appState.events.removeAll { $0.accountId == account.id }
    }

    private func toggleAccount(_ account: GoogleAccount, enabled: Bool) {
        if let index = appState.accounts.firstIndex(where: { $0.id == account.id }) {
            appState.accounts[index].isEnabled = enabled
            appState.saveAccounts()
        }
    }
}

struct AccountRowView: View {
    let account: GoogleAccount
    let onRemove: () -> Void
    let onToggle: (Bool) -> Void

    @State private var isEnabled: Bool

    init(account: GoogleAccount, onRemove: @escaping () -> Void, onToggle: @escaping (Bool) -> Void) {
        self.account = account
        self.onRemove = onRemove
        self.onToggle = onToggle
        self._isEnabled = State(initialValue: account.isEnabled)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.system(size: 13, weight: .medium))
                Text(account.email)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .onChange(of: isEnabled) { newValue in
                    onToggle(newValue)
                }

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("NeverMiss")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Never miss another meeting with smart calendar notifications")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
