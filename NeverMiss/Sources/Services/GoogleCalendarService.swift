import Foundation

class GoogleCalendarService {
    private let account: GoogleAccount

    init(account: GoogleAccount) {
        self.account = account
    }

    // MARK: - Fetch Events

    func fetchUpcomingEvents() async throws -> [CalendarEvent] {
        guard let accessToken = account.accessToken else {
            throw CalendarError.noAccessToken
        }

        // First get list of calendars
        let calendars = try await fetchCalendarList(accessToken: accessToken)

        // Fetch events from each calendar
        var allEvents: [CalendarEvent] = []

        for calendar in calendars {
            let events = try await fetchEventsFromCalendar(
                calendarId: calendar.id,
                accessToken: accessToken
            )
            allEvents.append(contentsOf: events)
        }

        return allEvents
    }

    // MARK: - Private Methods

    private func fetchCalendarList(accessToken: String) async throws -> [CalendarListEntry] {
        let url = URL(string: "\(Config.googleCalendarBaseURL)/users/me/calendarList")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CalendarError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw CalendarError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw CalendarError.requestFailed(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            throw CalendarError.invalidCalendarListResponse
        }

        return items.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            let summary = item["summary"] as? String ?? id
            let primary = item["primary"] as? Bool ?? false
            let selected = item["selected"] as? Bool ?? true
            let accessRole = item["accessRole"] as? String ?? "reader"

            // Only include calendars that are selected
            guard selected else { return nil }

            // Only include calendars the user owns (not shared calendars from others)
            // This filters out colleagues' calendars that are shared with the user
            guard accessRole == "owner" else { return nil }

            return CalendarListEntry(id: id, summary: summary, isPrimary: primary)
        }
    }

    private func fetchEventsFromCalendar(calendarId: String, accessToken: String) async throws -> [CalendarEvent] {
        let now = Date()
        let tomorrow = now.addingTimeInterval(24 * 60 * 60)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var components = URLComponents(string: "\(Config.googleCalendarBaseURL)/calendars/\(calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId)/events")!

        components.queryItems = [
            URLQueryItem(name: "timeMin", value: formatter.string(from: now)),
            URLQueryItem(name: "timeMax", value: formatter.string(from: tomorrow)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "50")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CalendarError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw CalendarError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw CalendarError.requestFailed(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            throw CalendarError.invalidEventsResponse
        }

        return items.compactMap { item in
            CalendarEvent(from: item, accountId: account.id, calendarId: calendarId, userEmail: account.email)
        }
    }
}

// MARK: - Supporting Types

struct CalendarListEntry {
    let id: String
    let summary: String
    let isPrimary: Bool
}

enum CalendarError: LocalizedError {
    case noAccessToken
    case invalidResponse
    case unauthorized
    case requestFailed(Int)
    case invalidCalendarListResponse
    case invalidEventsResponse

    var errorDescription: String? {
        switch self {
        case .noAccessToken:
            return "No access token available"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authorization expired. Please re-authenticate."
        case .requestFailed(let code):
            return "Request failed with status code \(code)"
        case .invalidCalendarListResponse:
            return "Invalid calendar list response"
        case .invalidEventsResponse:
            return "Invalid events response"
        }
    }
}
