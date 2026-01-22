import Foundation

struct CalendarEvent: Identifiable, Codable, Equatable {
    let id: String
    let accountId: String
    let calendarId: String
    let title: String
    let description: String?
    let location: String?
    let startTime: Date
    let endTime: Date
    let isAllDay: Bool
    let organizer: String?
    let attendees: [Attendee]
    let responseStatus: ResponseStatus
    let conferenceInfo: ConferenceInfo?
    let htmlLink: String?

    var hasConferenceLink: Bool {
        conferenceInfo?.joinUrl != nil
    }

    struct Attendee: Codable, Equatable {
        let email: String
        let displayName: String?
        let responseStatus: ResponseStatus
        let isSelf: Bool
    }

    enum ResponseStatus: String, Codable {
        case needsAction
        case declined
        case tentative
        case accepted

        init(from rawValue: String) {
            switch rawValue.lowercased() {
            case "accepted": self = .accepted
            case "declined": self = .declined
            case "tentative": self = .tentative
            default: self = .needsAction
            }
        }
    }

    struct ConferenceInfo: Codable, Equatable {
        let provider: ConferenceProvider
        let joinUrl: String?

        enum ConferenceProvider: String, Codable {
            case googleMeet
            case zoom
            case teams
            case webex
            case other
        }
    }
}

// MARK: - JSON Parsing from Google Calendar API

extension CalendarEvent {
    init?(from json: [String: Any], accountId: String, calendarId: String, userEmail: String) {
        guard let id = json["id"] as? String,
              let summary = json["summary"] as? String else {
            return nil
        }

        // Filter out non-meeting event types (working location, out of office, focus time)
        if let eventType = json["eventType"] as? String {
            print("[NeverMiss] Event '\(summary)' has eventType: \(eventType)")
            let excludedTypes = ["workinglocation", "outofoffice", "focustime"]
            if excludedTypes.contains(eventType.lowercased()) {
                print("[NeverMiss] Filtering out event '\(summary)' (eventType: \(eventType))")
                return nil
            }
        }

        self.id = "\(accountId)_\(id)"
        self.accountId = accountId
        self.calendarId = calendarId
        self.title = summary
        self.description = json["description"] as? String
        self.location = json["location"] as? String
        self.htmlLink = json["htmlLink"] as? String

        // Parse start/end times
        if let start = json["start"] as? [String: Any],
           let end = json["end"] as? [String: Any] {

            if let dateTimeStr = start["dateTime"] as? String {
                self.startTime = ISO8601DateFormatter().date(from: dateTimeStr) ?? Date()
                self.isAllDay = false
            } else if let dateStr = start["date"] as? String {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                self.startTime = formatter.date(from: dateStr) ?? Date()
                self.isAllDay = true
            } else {
                return nil
            }

            if let dateTimeStr = end["dateTime"] as? String {
                self.endTime = ISO8601DateFormatter().date(from: dateTimeStr) ?? Date()
            } else if let dateStr = end["date"] as? String {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                self.endTime = formatter.date(from: dateStr) ?? Date()
            } else {
                return nil
            }
        } else {
            return nil
        }

        // Parse organizer
        if let organizer = json["organizer"] as? [String: Any] {
            self.organizer = organizer["displayName"] as? String ?? organizer["email"] as? String
        } else {
            self.organizer = nil
        }

        // Parse attendees and find self's response status
        var attendeesList: [Attendee] = []
        // Default to accepted for personal events (no attendees = you created it, so you're "attending")
        var selfResponseStatus: ResponseStatus = .accepted

        if let attendeesJson = json["attendees"] as? [[String: Any]], !attendeesJson.isEmpty {
            for attendeeJson in attendeesJson {
                let email = attendeeJson["email"] as? String ?? ""
                let displayName = attendeeJson["displayName"] as? String
                let status = ResponseStatus(from: attendeeJson["responseStatus"] as? String ?? "needsAction")
                let isSelf = (attendeeJson["self"] as? Bool) ?? (email.lowercased() == userEmail.lowercased())

                let attendee = Attendee(
                    email: email,
                    displayName: displayName,
                    responseStatus: status,
                    isSelf: isSelf
                )
                attendeesList.append(attendee)

                if isSelf {
                    selfResponseStatus = status
                }
            }
        }

        self.attendees = attendeesList
        self.responseStatus = selfResponseStatus

        // Parse conference info
        self.conferenceInfo = CalendarEvent.parseConferenceInfo(from: json, description: self.description, location: self.location)
    }

    private static func parseConferenceInfo(from json: [String: Any], description: String?, location: String?) -> ConferenceInfo? {
        // First check native conference data (Google Meet)
        if let conferenceData = json["conferenceData"] as? [String: Any],
           let entryPoints = conferenceData["entryPoints"] as? [[String: Any]] {
            for entryPoint in entryPoints {
                if entryPoint["entryPointType"] as? String == "video",
                   let uri = entryPoint["uri"] as? String {
                    return ConferenceInfo(provider: .googleMeet, joinUrl: uri)
                }
            }
        }

        // Check for Zoom links in description or location
        let zoomPattern = #"https://[\w.-]*zoom\.us/j/\d+(\?pwd=[\w-]+)?"#
        if let url = extractUrl(matching: zoomPattern, from: description) ?? extractUrl(matching: zoomPattern, from: location) {
            return ConferenceInfo(provider: .zoom, joinUrl: url)
        }

        // Check for Teams links
        let teamsPattern = #"https://teams\.microsoft\.com/l/meetup-join/[\w%/-]+"#
        if let url = extractUrl(matching: teamsPattern, from: description) ?? extractUrl(matching: teamsPattern, from: location) {
            return ConferenceInfo(provider: .teams, joinUrl: url)
        }

        // Check for Webex links
        let webexPattern = #"https://[\w.-]*webex\.com/[\w/-]+/j\.php\?[\w=&-]+"#
        if let url = extractUrl(matching: webexPattern, from: description) ?? extractUrl(matching: webexPattern, from: location) {
            return ConferenceInfo(provider: .webex, joinUrl: url)
        }

        return nil
    }

    private static func extractUrl(matching pattern: String, from text: String?) -> String? {
        guard let text = text else { return nil }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range) {
            return String(text[Range(match.range, in: text)!])
        }

        return nil
    }
}
