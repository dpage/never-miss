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
        appState.$nextMeetings
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

        let meetings = appState.nextMeetings

        if meetings.isEmpty {
            button.title = "No upcoming meetings"
        } else if meetings.count == 1 {
            let meeting = meetings[0]
            let timeString = TimeFormatting.relativeTime(to: meeting.startTime)
            button.title = "\(meeting.title) \(timeString)"
        } else {
            // Check if multiple meetings start at the same time
            let firstStartTime = meetings[0].startTime
            let sameTiMeetings = meetings.filter {
                abs($0.startTime.timeIntervalSince(firstStartTime)) < 60
            }

            if sameTiMeetings.count > 1 {
                let timeString = TimeFormatting.relativeTime(to: firstStartTime)
                button.title = "\(sameTiMeetings.count) meetings \(timeString)"
            } else {
                let meeting = meetings[0]
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
    @Published var nextMeetings: [CalendarEvent] = []
    @Published var settings: AppSettings = AppSettings.load()
    @Published var isAuthenticating: Bool = false

    var cancellables = Set<AnyCancellable>()

    init() {
        loadAccounts()
        updateNextMeetings()

        // Update next meetings when events change
        $events
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

    func updateNextMeetings() {
        let now = Date()
        let filtered = events
            .filter { event in
                // Include future events OR in-progress events (started but not ended)
                let isFuture = event.startTime > now
                let isInProgress = event.startTime <= now && event.endTime > now
                guard isFuture || isInProgress else { return false }

                // Filter by accepted status if enabled
                if settings.showOnlyAccepted {
                    return event.responseStatus == .accepted
                }
                return true
            }
            .sorted { $0.startTime < $1.startTime }

        // Get meetings starting within the next 24 hours (or currently in progress)
        let cutoff = now.addingTimeInterval(24 * 60 * 60)
        nextMeetings = Array(filtered.filter { $0.startTime < cutoff || $0.endTime > now }.prefix(10))
    }
}

import Combine
