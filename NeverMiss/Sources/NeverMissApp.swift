import SwiftUI
import AppKit

@main
struct NeverMissApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty WindowGroup - we manage everything via AppDelegate
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var appState = AppState()
    var calendarSyncService: CalendarSyncService?
    var notificationService: NotificationService?
    var syncTimer: Timer?
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupServices()
        startSyncTimer()
        setupNotificationObservers()

        // Hide dock icon - this is a menu bar only app
        NSApp.setActivationPolicy(.accessory)
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: Notification.Name("openSettings"),
            object: nil
        )
    }

    @objc private func openSettings() {
        // Close the popover first
        popover?.performClose(nil)

        // If settings window already exists, just bring it to front
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create settings window
        let settingsView = SettingsView()
            .environmentObject(appState)

        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "NeverMiss Settings"
        window.styleMask = [.titled, .closable]
        window.setFrameAutosaveName("")  // Disable frame autosave to avoid warning
        window.setContentSize(NSSize(width: 500, height: 600))
        window.center()
        window.isReleasedWhenClosed = false

        settingsWindow = window

        // Show the window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.action = #selector(togglePopover)
            button.target = self
            updateMenuBarTitle()
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 360, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MenuDropdownView()
                .environmentObject(appState)
        )

        // Observe app state changes to update menu bar
        appState.$timedMeetings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarTitle()
            }
            .store(in: &appState.cancellables)

        appState.$allDayEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarTitle()
            }
            .store(in: &appState.cancellables)
    }

    private func setupServices() {
        calendarSyncService = CalendarSyncService(appState: appState)
        notificationService = NotificationService(appState: appState)

        // Initial sync
        Task {
            await calendarSyncService?.syncAllAccounts()
        }
    }

    private func startSyncTimer() {
        let interval = appState.settings.refreshInterval
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.calendarSyncService?.syncAllAccounts()
            }
        }

        // Also update the menu bar title every minute
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMenuBarTitle()
            }
        }
    }

    func updateMenuBarTitle() {
        guard let button = statusItem?.button else { return }

        let timedMeetings = appState.timedMeetings
        let allDayEvents = appState.allDayEvents

        // Prioritize timed meetings over all-day events
        if timedMeetings.isEmpty && allDayEvents.isEmpty {
            button.title = "No upcoming meetings"
        } else if timedMeetings.isEmpty {
            // Only all-day events
            if allDayEvents.count == 1 {
                button.title = "\(allDayEvents[0].title) (All day)"
            } else {
                button.title = "\(allDayEvents.count) all-day events"
            }
        } else {
            // Show timed meetings (prioritize over all-day)
            let firstStartTime = timedMeetings[0].startTime
            let sameTiMeetings = timedMeetings.filter {
                abs($0.startTime.timeIntervalSince(firstStartTime)) < 60
            }

            if sameTiMeetings.count > 1 {
                let timeString = TimeFormatting.relativeTime(to: firstStartTime)
                button.title = "\(sameTiMeetings.count) meetings \(timeString)"
            } else {
                let meeting = timedMeetings[0]
                let timeString = TimeFormatting.relativeTime(to: meeting.startTime)
                button.title = "\(meeting.title) \(timeString)"
            }
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func showMeetingPopup(for event: CalendarEvent) {
        notificationService?.showPopup(for: event)
    }
}

// Observable app state shared across views
class AppState: ObservableObject {
    @Published var accounts: [GoogleAccount] = []
    @Published var events: [CalendarEvent] = []
    @Published var nextMeetings: [CalendarEvent] = []      // All upcoming (for compatibility)
    @Published var allDayEvents: [CalendarEvent] = []      // All-day events (reminders, birthdays)
    @Published var timedMeetings: [CalendarEvent] = []     // Timed meetings (with specific times)
    @Published var settings: AppSettings = AppSettings.load()
    @Published var isAuthenticating: Bool = false
    @Published var dismissedEventIds: Set<String> = []

    var cancellables = Set<AnyCancellable>()

    private let dismissedEventsKey = "dismissedEventIds"

    init() {
        loadAccounts()
        loadDismissedEvents()
        updateNextMeetings()

        // Update next meetings when events change
        $events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateNextMeetings()
            }
            .store(in: &cancellables)

        // Also update when dismissed events change
        $dismissedEventIds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateNextMeetings()
            }
            .store(in: &cancellables)
    }

    func loadAccounts() {
        accounts = GoogleAccount.loadAll()
    }

    func saveAccounts() {
        GoogleAccount.saveAll(accounts)
    }

    func loadDismissedEvents() {
        if let ids = UserDefaults.standard.array(forKey: dismissedEventsKey) as? [String] {
            dismissedEventIds = Set(ids)
        }
    }

    func dismissEvent(_ eventId: String) {
        dismissedEventIds.insert(eventId)
        UserDefaults.standard.set(Array(dismissedEventIds), forKey: dismissedEventsKey)
    }

    func undismissEvent(_ eventId: String) {
        dismissedEventIds.remove(eventId)
        UserDefaults.standard.set(Array(dismissedEventIds), forKey: dismissedEventsKey)
    }

    func clearDismissedEvents() {
        dismissedEventIds.removeAll()
        UserDefaults.standard.removeObject(forKey: dismissedEventsKey)
    }

    func updateNextMeetings() {
        let now = Date()
        let todayStart = Calendar.current.startOfDay(for: now)
        let cutoff = now.addingTimeInterval(24 * 60 * 60)

        let filtered = events
            .filter { event in
                // Exclude dismissed events
                guard !dismissedEventIds.contains(event.id) else { return false }

                // Include future events OR in-progress events (started but not ended)
                let isFuture = event.startTime > now
                let isInProgress = event.startTime <= now && event.endTime > now
                // For all-day events, check if they're today or future
                let isAllDayToday = event.isAllDay && event.startTime >= todayStart
                guard isFuture || isInProgress || isAllDayToday else { return false }

                // Filter by accepted status if enabled
                if settings.showOnlyAccepted {
                    return event.responseStatus == .accepted
                }
                return true
            }
            .sorted { $0.startTime < $1.startTime }

        // Separate all-day events from timed events
        allDayEvents = filtered.filter { $0.isAllDay && $0.startTime < cutoff }
        timedMeetings = Array(filtered.filter { !$0.isAllDay && ($0.startTime < cutoff || $0.endTime > now) }.prefix(10))

        // Combined list (timed first, then all-day) for compatibility
        nextMeetings = timedMeetings + allDayEvents
    }
}

import Combine
