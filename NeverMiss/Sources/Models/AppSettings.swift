import Foundation

struct AppSettings: Codable, Equatable {
    var refreshInterval: TimeInterval
    var notificationLeadTime: TimeInterval
    var showOnlyAccepted: Bool
    var launchAtLogin: Bool
    var showPopupNotifications: Bool
    var playSound: Bool

    static let defaultRefreshInterval: TimeInterval = 300 // 5 minutes
    static let defaultNotificationLeadTime: TimeInterval = 300 // 5 minutes

    init() {
        self.refreshInterval = Self.defaultRefreshInterval
        self.notificationLeadTime = Self.defaultNotificationLeadTime
        self.showOnlyAccepted = false
        self.launchAtLogin = false
        self.showPopupNotifications = true
        self.playSound = true
    }

    private static let settingsKey = "nevermiss.settings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }
}

// MARK: - Preset Options

extension AppSettings {
    static let refreshIntervalOptions: [(String, TimeInterval)] = [
        ("1 minute", 60),
        ("5 minutes", 300),
        ("15 minutes", 900)
    ]

    static let notificationLeadTimeOptions: [(String, TimeInterval)] = [
        ("1 minute before", 60),
        ("2 minutes before", 120),
        ("5 minutes before", 300),
        ("10 minutes before", 600),
        ("15 minutes before", 900)
    ]
}
