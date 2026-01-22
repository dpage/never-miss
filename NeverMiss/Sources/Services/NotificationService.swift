import Foundation
import Combine

class NotificationService {
    private weak var appState: AppState?
    private var scheduledNotifications: [String: Timer] = [:]
    private var shownNotifications: Set<String> = []
    private var popupController = MeetingPopupWindowController()
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        setupEventObserver()
        startNotificationChecker()
    }

    private func setupEventObserver() {
        appState?.$events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] events in
                self?.scheduleNotifications(for: events)
            }
            .store(in: &cancellables)

        appState?.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Re-schedule when settings change
                if let events = self?.appState?.events {
                    self?.scheduleNotifications(for: events)
                }
            }
            .store(in: &cancellables)
    }

    private func startNotificationChecker() {
        // Check every 30 seconds for notifications to show
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkForUpcomingMeetings()
        }
    }

    private func scheduleNotifications(for events: [CalendarEvent]) {
        guard let settings = appState?.settings, settings.showPopupNotifications else {
            // Cancel all scheduled notifications
            cancelAllNotifications()
            return
        }

        let now = Date()
        let leadTime = settings.notificationLeadTime

        // Cancel existing timers
        cancelAllNotifications()

        for event in events {
            // Skip if already shown
            guard !shownNotifications.contains(event.id) else { continue }

            // Skip if not accepted (when filter is enabled)
            if settings.showOnlyAccepted && event.responseStatus != .accepted {
                continue
            }

            // Calculate when to show notification
            let notificationTime = event.startTime.addingTimeInterval(-leadTime)

            // Skip if notification time has passed
            guard notificationTime > now else {
                // Check if the meeting is still upcoming and we should show now
                if event.startTime > now && event.startTime.timeIntervalSince(now) <= leadTime {
                    // Show immediately
                    showPopup(for: event)
                }
                continue
            }

            // Schedule timer
            let delay = notificationTime.timeIntervalSince(now)
            let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.showPopup(for: event)
            }
            scheduledNotifications[event.id] = timer
        }
    }

    private func checkForUpcomingMeetings() {
        guard let appState = appState else { return }
        let settings = appState.settings

        guard settings.showPopupNotifications else { return }

        let now = Date()
        let leadTime = settings.notificationLeadTime

        for event in appState.events {
            // Skip if already shown
            guard !shownNotifications.contains(event.id) else { continue }

            // Skip if not accepted (when filter is enabled)
            if settings.showOnlyAccepted && event.responseStatus != .accepted {
                continue
            }

            // Check if it's time to show the notification
            let notificationTime = event.startTime.addingTimeInterval(-leadTime)

            if now >= notificationTime && event.startTime > now {
                showPopup(for: event)
            }
        }
    }

    func showPopup(for event: CalendarEvent) {
        guard !shownNotifications.contains(event.id) else { return }

        shownNotifications.insert(event.id)
        scheduledNotifications[event.id]?.invalidate()
        scheduledNotifications.removeValue(forKey: event.id)

        DispatchQueue.main.async { [weak self] in
            self?.popupController.show(for: event)
        }
    }

    private func cancelAllNotifications() {
        for timer in scheduledNotifications.values {
            timer.invalidate()
        }
        scheduledNotifications.removeAll()
    }

    func clearShownNotifications() {
        // Clear the set of shown notifications at midnight
        shownNotifications.removeAll()
    }

    deinit {
        cancelAllNotifications()
    }
}
