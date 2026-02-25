import Foundation

private let googleCalendarAPIRoot = "https://www.googleapis.com/calendar/v3"
private let defaultCalendarID = "primary"
private let autoEventHelperText = "To see detailed information for automatically created events like this one, use the official Google Calendar app."
private let autoEventMarker = "to see detailed information for automatically created events"

private let googleEventColors: [String: String] = [
    "1": "#7986cbff",
    "2": "#33b679ff",
    "3": "#8e24aaff",
    "4": "#e67c73ff",
    "5": "#f6bf26ff",
    "6": "#f4511eff",
    "7": "#039be5ff",
    "8": "#616161ff",
    "9": "#3f51b5ff",
    "10": "#0b8043ff",
    "11": "#d50000ff"
]

struct GoogleCalendarService {
    func getEventsForYear(year: Int, accessToken: String, calendarID: String?) async throws -> [CalendarEvent] {
        let trimmedCalendarID = calendarID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let safeCalendarID = trimmedCalendarID.isEmpty ? defaultCalendarID : trimmedCalendarID

        var events: [CalendarEvent] = []
        var pageToken: String? = nil

        repeat {
            let url = buildEventsURL(year: year, calendarID: safeCalendarID, pageToken: pageToken)
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CalendarError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw CalendarError.sessionExpired
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw CalendarError.requestFailed(statusCode: httpResponse.statusCode)
            }

            let payload = try JSONDecoder().decode(GoogleCalendarEventsResponse.self, from: data)
            for item in payload.items ?? [] {
                if let mapped = mapGoogleEvent(item) {
                    events.append(mapped)
                }
            }

            pageToken = payload.nextPageToken
        } while pageToken != nil

        return events
    }

    private func buildEventsURL(year: Int, calendarID: String, pageToken: String?) -> URL {
        var components = URLComponents(string: "\(googleCalendarAPIRoot)/calendars/\(calendarID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarID)/events")!

        var queryItems = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "showDeleted", value: "false"),
            URLQueryItem(name: "maxResults", value: "2500"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "timeMin", value: getRangeStart(year: year).iso8601String()),
            URLQueryItem(name: "timeMax", value: getRangeEnd(year: year).iso8601String())
        ]

        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        components.queryItems = queryItems
        return components.url!
    }

    private func mapGoogleEvent(_ event: GoogleCalendarEvent) -> CalendarEvent? {
        guard let id = event.id, !id.isEmpty,
              let start = event.start,
              let end = event.end else {
            return nil
        }

        let hasDateTime = start.dateTime != nil && end.dateTime != nil
        var startDate: Date?
        var endDate: Date?

        if hasDateTime {
            if let startRaw = start.dateTime, let endRaw = end.dateTime {
                startDate = parseDate(startRaw)
                endDate = parseDate(endRaw)
            }
        } else if let startRaw = start.date, let endRaw = end.date {
            startDate = parseAllDayDate(startRaw)
            if let allDayEndExclusive = parseAllDayDate(endRaw) {
                endDate = allDayEndExclusive.addingTimeInterval(-1)
            }
        }

        guard let safeStart = startDate,
              let safeEnd = endDate,
              safeEnd >= safeStart else {
            return nil
        }

        let summary = event.summary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? event.summary!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "Untitled event"

        let description: String
        let trimmedDescription = event.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedDescription.isEmpty {
            description = buildFallbackDescription(event)
        } else {
            description = trimmedDescription
        }

        let isAutoCreated = isAutomaticallyCreated(event, description: description)
        let originalEmailURL = isAutoCreated ? parseOriginalEmailURL(primaryURL: event.source?.url, fallbackText: description) : nil

        return CalendarEvent(
            id: id,
            summary: summary,
            description: description,
            start: safeStart,
            end: safeEnd,
            location: event.location ?? "",
            color: resolveEventColor(event.colorId),
            status: event.status,
            isAllDay: !hasDateTime,
            calendarURL: URL(string: event.htmlLink ?? ""),
            isAutomaticallyCreated: isAutoCreated,
            originalEmailURL: originalEmailURL
        )
    }

    private func parseDate(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter.full.date(from: value) {
            return date
        }

        if let date = ISO8601DateFormatter.internet.date(from: value) {
            return date
        }

        if let date = DateFormatter.localDateTime.date(from: value) {
            return date
        }

        let fallback = ISO8601DateFormatter()
        return fallback.date(from: value)
    }

    private func parseAllDayDate(_ value: String) -> Date? {
        DateFormatter.googleAllDay.date(from: value)
    }

    private func isAutomaticallyCreated(_ event: GoogleCalendarEvent, description: String) -> Bool {
        let sourceTitle = event.source?.title?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if sourceTitle.contains(autoEventMarker) || sourceTitle == autoEventHelperText.lowercased() {
            return true
        }

        if description.lowercased().contains(autoEventMarker) {
            return true
        }

        if let sourceURL = event.source?.url?.lowercased(),
           sourceURL.contains("mail.google.com") {
            return true
        }

        return false
    }

    private func parseOriginalEmailURL(primaryURL rawURL: String?, fallbackText: String) -> URL? {
        if let rawURL = rawURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawURL.isEmpty,
           let url = URL(string: rawURL),
           isOriginalEmailURL(url) {
            return url
        }

        return detectURLs(in: fallbackText).first(where: isOriginalEmailURL)
    }

    private func isOriginalEmailURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("mail.google.com")
    }

    private func detectURLs(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let range = NSRange(location: 0, length: text.utf16.count)
        return detector.matches(in: text, options: [], range: range).compactMap(\.url)
    }

    private func resolveEventColor(_ rawColorID: String?) -> String {
        guard let rawColorID else {
            return "#0859dbff"
        }

        return googleEventColors[rawColorID] ?? "#0859dbff"
    }

    private func buildFallbackDescription(_ event: GoogleCalendarEvent) -> String {
        var lines: [String] = []

        if let sourceTitle = event.source?.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sourceTitle.isEmpty,
           sourceTitle != autoEventHelperText {
            lines.append(sourceTitle)
        }

        if let sourceURL = event.source?.url?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sourceURL.isEmpty,
           !sourceURL.contains("g.co/calendar") {
            lines.append(sourceURL)
        }

        if let hangoutLink = event.hangoutLink?.trimmingCharacters(in: .whitespacesAndNewlines),
           !hangoutLink.isEmpty {
            lines.append("Meeting link: \(hangoutLink)")
        }

        for entryPoint in event.conferenceData?.entryPoints ?? [] {
            let uri = entryPoint.uri?.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = entryPoint.label?.trimmingCharacters(in: .whitespacesAndNewlines)

            if let label, !label.isEmpty, let uri, !uri.isEmpty {
                lines.append("\(label): \(uri)")
            } else if let label, !label.isEmpty {
                lines.append(label)
            } else if let uri, !uri.isEmpty {
                lines.append(uri)
            }
        }

        for attachment in event.attachments ?? [] {
            let title = attachment.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fileURL = attachment.fileUrl?.trimmingCharacters(in: .whitespacesAndNewlines)

            if let title, !title.isEmpty, let fileURL, !fileURL.isEmpty {
                lines.append("Attachment: \(title) (\(fileURL))")
            } else if let title, !title.isEmpty {
                lines.append("Attachment: \(title)")
            } else if let fileURL, !fileURL.isEmpty {
                lines.append("Attachment: \(fileURL)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func getRangeStart(year: Int) -> Date {
        let date = DateComponents(calendar: .gregorianUTC, timeZone: TimeZone(secondsFromGMT: 0), year: year, month: 1, day: 1)
        let start = date.date ?? Date()
        return Calendar.gregorianUTC.date(byAdding: .day, value: -31, to: start) ?? start
    }

    private func getRangeEnd(year: Int) -> Date {
        let date = DateComponents(calendar: .gregorianUTC, timeZone: TimeZone(secondsFromGMT: 0), year: year + 1, month: 1, day: 1)
        let end = date.date ?? Date()
        return Calendar.gregorianUTC.date(byAdding: .day, value: 31, to: end) ?? end
    }
}

enum CalendarError: LocalizedError {
    case invalidResponse
    case requestFailed(statusCode: Int)
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Google Calendar returned an invalid response."
        case .requestFailed(let statusCode):
            return "Google Calendar request failed (\(statusCode))."
        case .sessionExpired:
            return "Google session expired. Please sign in again."
        }
    }
}

private struct GoogleCalendarEventsResponse: Decodable {
    let items: [GoogleCalendarEvent]?
    let nextPageToken: String?
}

private struct GoogleCalendarEvent: Decodable {
    struct Source: Decodable {
        let title: String?
        let url: String?
    }

    struct Attachment: Decodable {
        let title: String?
        let fileUrl: String?
    }

    struct ConferenceData: Decodable {
        struct EntryPoint: Decodable {
            let uri: String?
            let label: String?
            let entryPointType: String?
        }

        let entryPoints: [EntryPoint]?
    }

    struct EventDate: Decodable {
        let date: String?
        let dateTime: String?
    }

    let id: String?
    let summary: String?
    let description: String?
    let location: String?
    let colorId: String?
    let status: String?
    let htmlLink: String?
    let source: Source?
    let hangoutLink: String?
    let conferenceData: ConferenceData?
    let attachments: [Attachment]?
    let start: EventDate?
    let end: EventDate?
}

private extension Calendar {
    static let gregorianUTC: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()
}

private extension ISO8601DateFormatter {
    static let full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let internet: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private extension DateFormatter {
    static let googleAllDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let localDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}

private extension Date {
    func iso8601String() -> String {
        ISO8601DateFormatter.full.string(from: self)
    }
}
