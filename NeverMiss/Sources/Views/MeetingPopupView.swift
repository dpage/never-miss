import SwiftUI
import AppKit

enum MeetingStatus {
    case upcoming
    case inProgress
    case finished
}

struct MeetingPopupView: View {
    let event: CalendarEvent
    let onDismiss: () -> Void
    let onJoin: () -> Void

    @State private var currentTime = Date()

    // Timer to update the countdown
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var meetingStatus: MeetingStatus {
        let now = currentTime
        if now >= event.endTime {
            return .finished
        } else if now >= event.startTime {
            return .inProgress
        } else {
            return .upcoming
        }
    }

    private var statusText: String {
        switch meetingStatus {
        case .upcoming: return "Meeting Starting Soon"
        case .inProgress: return "Meeting In Progress"
        case .finished: return "Meeting Finished"
        }
    }

    private var statusIcon: String {
        switch meetingStatus {
        case .upcoming: return "bell.fill"
        case .inProgress: return "video.fill"
        case .finished: return "checkmark.circle.fill"
        }
    }

    private var chipText: String {
        switch meetingStatus {
        case .upcoming:
            return TimeFormatting.relativeTime(to: event.startTime)
        case .inProgress:
            return "In progress"
        case .finished:
            return "Finished"
        }
    }

    private var gradientColors: [Color] {
        switch meetingStatus {
        case .upcoming:
            return [Color.blue, Color.purple]
        case .inProgress:
            return [Color.green, Color.teal]
        case .finished:
            return [Color.orange, Color.red]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: statusIcon)
                        .font(.system(size: 16))
                    Text(statusText)
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text(chipText)
                        .font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                }
                .foregroundColor(.white)
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .onReceive(timer) { _ in
                currentTime = Date()
            }

            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Meeting title
                Text(event.title)
                    .font(.system(size: 24, weight: .bold))
                    .lineLimit(2)

                // Time
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    if event.isAllDay {
                        Text("All day")
                    } else {
                        Text(TimeFormatting.timeRange(start: event.startTime, end: event.endTime))
                        Text("(\(TimeFormatting.duration(from: event.startTime, to: event.endTime)))")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.system(size: 14))

                // Location or conference
                if event.hasConferenceLink {
                    HStack(spacing: 8) {
                        Image(systemName: conferenceIcon)
                            .foregroundColor(.secondary)
                        Text(conferenceName)
                            .font(.system(size: 14))
                    }
                } else if let location = event.location, !location.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.system(size: 14))
                            .lineLimit(2)
                    }
                }

                // Organizer
                if let organizer = event.organizer {
                    HStack(spacing: 8) {
                        Image(systemName: "person")
                            .foregroundColor(.secondary)
                        Text("Organized by \(organizer)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                // Attendees
                if !event.attendees.isEmpty && event.attendees.count <= 10 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2")
                                .foregroundColor(.secondary)
                            Text("\(event.attendees.count) attendee\(event.attendees.count == 1 ? "" : "s")")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        WrappingHStack(spacing: 6) {
                            ForEach(event.attendees.prefix(8), id: \.email) { attendee in
                                AttendeeChip(attendee: attendee)
                            }
                            if event.attendees.count > 8 {
                                Text("+\(event.attendees.count - 8)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }

                // Description
                if let description = event.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        Text(cleanDescription(description))
                            .font(.system(size: 13))
                            .lineLimit(4)
                            .foregroundColor(.primary.opacity(0.8))
                    }
                    .padding(.top, 8)
                }

                Spacer(minLength: 0)

                // Action buttons
                HStack(spacing: 12) {
                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    if event.hasConferenceLink {
                        Button(action: onJoin) {
                            HStack {
                                Image(systemName: "video.fill")
                                Text("Join Meeting")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else if let htmlLink = event.htmlLink {
                        Button(action: {
                            if let url = URL(string: htmlLink) {
                                NSWorkspace.shared.open(url)
                            }
                            onDismiss()
                        }) {
                            HStack {
                                Image(systemName: "calendar")
                                Text("Open in Calendar")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
            }
            .padding(24)
        }
        .frame(width: 450, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var conferenceIcon: String {
        guard let info = event.conferenceInfo else { return "video" }
        switch info.provider {
        case .googleMeet: return "video"
        case .zoom: return "video.fill"
        case .teams: return "person.2.fill"
        case .webex: return "video.badge.checkmark"
        case .other: return "video"
        }
    }

    private var conferenceName: String {
        guard let info = event.conferenceInfo else { return "Video call" }
        switch info.provider {
        case .googleMeet: return "Google Meet"
        case .zoom: return "Zoom Meeting"
        case .teams: return "Microsoft Teams"
        case .webex: return "Webex Meeting"
        case .other: return "Video call"
        }
    }

    private func cleanDescription(_ text: String) -> String {
        // Remove HTML tags and clean up the description
        var cleaned = text
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")

        // Remove excessive whitespace
        cleaned = cleaned.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return cleaned
    }
}

struct AttendeeChip: View {
    let attendee: CalendarEvent.Attendee

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(displayName)
                .font(.system(size: 11))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }

    private var displayName: String {
        if let name = attendee.displayName, !name.isEmpty {
            return name.components(separatedBy: " ").first ?? name
        }
        return attendee.email.components(separatedBy: "@").first ?? attendee.email
    }

    private var statusColor: Color {
        switch attendee.responseStatus {
        case .accepted: return .green
        case .tentative: return .yellow
        case .declined: return .red
        case .needsAction: return .gray
        }
    }
}

// MARK: - Wrapping Layout

struct WrappingHStack: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return (CGSize(width: totalWidth, height: currentY + rowHeight), positions)
    }
}

// MARK: - Popup Window Controller

class MeetingPopupWindowController {
    private var window: NSWindow?
    private var event: CalendarEvent?

    func show(for event: CalendarEvent) {
        // Close existing window if any
        close()

        self.event = event

        let popupView = MeetingPopupView(
            event: event,
            onDismiss: { [weak self] in
                self?.close()
            },
            onJoin: { [weak self] in
                self?.joinMeeting()
            }
        )

        let hostingController = NSHostingController(rootView: popupView)

        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Set the content size first
        window.setContentSize(NSSize(width: 450, height: 500))

        // Center on the main screen
        window.center()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Play sound if enabled
        let settings = AppSettings.load()
        if settings.playSound {
            NSSound(named: "Glass")?.play()
        }

        self.window = window
    }

    func close() {
        window?.close()
        window = nil
        event = nil
    }

    private func joinMeeting() {
        guard let event = event,
              let joinUrl = event.conferenceInfo?.joinUrl,
              let url = URL(string: joinUrl) else { return }

        NSWorkspace.shared.open(url)
        close()
    }
}
