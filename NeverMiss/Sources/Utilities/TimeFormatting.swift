import Foundation

struct TimeFormatting {
    /// Returns a relative time string like "in 5 min" or "in 2 hr"
    static func relativeTime(to date: Date, from now: Date = Date()) -> String {
        let interval = date.timeIntervalSince(now)

        if interval <= 0 {
            return "now"
        }

        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if minutes < 1 {
            return "in < 1 min"
        } else if minutes == 1 {
            return "in 1 min"
        } else if minutes < 60 {
            return "in \(minutes) min"
        } else if hours == 1 {
            let remainingMinutes = minutes - 60
            if remainingMinutes > 0 {
                return "in 1 hr \(remainingMinutes) min"
            }
            return "in 1 hr"
        } else if hours < 24 {
            return "in \(hours) hr"
        } else if days == 1 {
            return "tomorrow"
        } else {
            return "in \(days) days"
        }
    }

    /// Returns a formatted time range string like "2:00 PM - 3:00 PM"
    static func timeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    /// Returns a formatted date and time string like "Mon, Jan 15 at 2:00 PM"
    static func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    /// Returns just the time like "2:00 PM"
    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    /// Returns duration in a readable format like "1 hour" or "30 minutes"
    static func duration(from start: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else if remainingMinutes == 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "\(hours) hr \(remainingMinutes) min"
        }
    }
}
