import Foundation

let WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
let MAX_VISIBLE_BARS = 3
let MAX_VISIBLE_TIMED = 3

struct MonthStartLabel {
    let full: String
    let short: String
}

struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let summary: String
    let description: String
    let start: Date
    let end: Date
    let location: String
    let color: String
    let status: String?
    let isAllDay: Bool
    let calendarURL: URL?
    let isAutomaticallyCreated: Bool
    let originalEmailURL: URL?
}

struct WeekBar: Identifiable, Hashable {
    let event: CalendarEvent
    let lane: Int
    let startIdx: Int
    let endIdx: Int
    let continuesFromPreviousWeek: Bool
    let continuesToNextWeek: Bool

    var id: String {
        "\(event.id)-\(lane)-\(startIdx)-\(endIdx)"
    }
}

struct WeekRenderData {
    let weekBars: [WeekBar]
    let shortEventsByDateKey: [String: [CalendarEvent]]
    let overflowBarsByDateKey: [String: Int]
    let activeBarsByDateKey: [String: Int]
}

private struct Placement {
    let event: CalendarEvent
    let startIdx: Int
    let endIdx: Int
    let continuesFromPreviousWeek: Bool
    let continuesToNextWeek: Bool
}

enum YearLayout {
    private static let daySeconds: TimeInterval = 24 * 60 * 60
    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal
    }

    static func isValidYear(_ value: Int) -> Bool {
        value >= 1 && value <= 9999
    }

    static func formatDateKey(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func formatEventTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    static func formatEventDateTime(_ date: Date) -> String {
        Self.dateTimeFormatter.string(from: date)
    }

    static func buildYearWeeks(year: Int) -> [[Date]] {
        guard let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let dec31 = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) else {
            return []
        }

        let start = startOfWeekMonday(jan1)
        let end = endOfWeekMonday(dec31)
        var cursor = start
        var weeks: [[Date]] = []

        while cursor <= end {
            var week: [Date] = []
            for offset in 0..<7 {
                week.append(addDays(cursor, offset))
            }
            weeks.append(week)
            cursor = addDays(cursor, 7)
        }

        return weeks
    }

    static func buildMonthStartLabels(weeks: [[Date]]) -> [String: MonthStartLabel] {
        var labels: [String: MonthStartLabel] = [:]

        for week in weeks {
            for date in week {
                let day = calendar.component(.day, from: date)
                if day != 1 {
                    continue
                }

                let key = formatDateKey(date)
                labels[key] = MonthStartLabel(
                    full: monthFormatter.string(from: date),
                    short: monthShortFormatter.string(from: date)
                )
            }
        }

        return labels
    }

    static func buildWeekRenderData(week: [Date], events: [CalendarEvent]) -> WeekRenderData {
        let weekKeys = week.map(formatDateKey)
        let weekStart = startOfDay(week[0])
        let weekEnd = startOfDay(week[6])

        var shortEventsByDateKey = Dictionary(uniqueKeysWithValues: weekKeys.map { ($0, [CalendarEvent]()) })
        var placements: [Placement] = []

        for event in events {
            if isShortEvent(event) {
                let key = formatDateKey(event.start)
                if shortEventsByDateKey[key] != nil {
                    shortEventsByDateKey[key, default: []].append(event)
                }
                continue
            }

            let eventStartDay = startOfDay(event.start)
            let eventEndDay = startOfDay(event.end)
            if !intersectsRange(startA: eventStartDay, endA: eventEndDay, startB: weekStart, endB: weekEnd) {
                continue
            }

            let startIdx = max(0, daysBetween(start: weekStart, end: eventStartDay))
            let endIdx = min(6, daysBetween(start: weekStart, end: eventEndDay))

            placements.append(
                Placement(
                    event: event,
                    startIdx: startIdx,
                    endIdx: endIdx,
                    continuesFromPreviousWeek: eventStartDay < weekStart,
                    continuesToNextWeek: eventEndDay > weekEnd
                )
            )
        }

        placements.sort { lhs, rhs in
            if lhs.startIdx != rhs.startIdx {
                return lhs.startIdx < rhs.startIdx
            }

            let lhsLength = lhs.endIdx - lhs.startIdx
            let rhsLength = rhs.endIdx - rhs.startIdx
            if lhsLength != rhsLength {
                return lhsLength > rhsLength
            }

            return lhs.event.start < rhs.event.start
        }

        var laneEndIndexes: [Int] = []
        var allWeekBars: [WeekBar] = []

        for placement in placements {
            var lane = 0
            while lane < laneEndIndexes.count {
                if placement.startIdx > laneEndIndexes[lane] {
                    break
                }
                lane += 1
            }

            if lane == laneEndIndexes.count {
                laneEndIndexes.append(-1)
            }

            laneEndIndexes[lane] = placement.endIdx
            allWeekBars.append(
                WeekBar(
                    event: placement.event,
                    lane: lane,
                    startIdx: placement.startIdx,
                    endIdx: placement.endIdx,
                    continuesFromPreviousWeek: placement.continuesFromPreviousWeek,
                    continuesToNextWeek: placement.continuesToNextWeek
                )
            )
        }

        var overflowBarsByDateKey = Dictionary(uniqueKeysWithValues: weekKeys.map { ($0, 0) })
        var activeBarsByDateKey = Dictionary(uniqueKeysWithValues: weekKeys.map { ($0, 0) })

        for dayIdx in 0..<weekKeys.count {
            let key = weekKeys[dayIdx]
            let activeBars = allWeekBars.filter { $0.startIdx <= dayIdx && $0.endIdx >= dayIdx }
            activeBarsByDateKey[key] = activeBars.count
            overflowBarsByDateKey[key] = max(0, activeBars.count - MAX_VISIBLE_BARS)

            shortEventsByDateKey[key]?.sort { $0.start < $1.start }
        }

        let weekBars = allWeekBars
            .filter { $0.lane < MAX_VISIBLE_BARS }
            .sorted {
                if $0.lane != $1.lane {
                    return $0.lane < $1.lane
                }
                if $0.startIdx != $1.startIdx {
                    return $0.startIdx < $1.startIdx
                }
                return $0.event.start < $1.event.start
            }

        return WeekRenderData(
            weekBars: weekBars,
            shortEventsByDateKey: shortEventsByDateKey,
            overflowBarsByDateKey: overflowBarsByDateKey,
            activeBarsByDateKey: activeBarsByDateKey
        )
    }

    private static func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    private static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private static func startOfWeekMonday(_ date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let dayIndex = (weekday + 5) % 7
        return addDays(startOfDay(date), -dayIndex)
    }

    private static func endOfWeekMonday(_ date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let dayIndex = (weekday + 5) % 7
        return addDays(startOfDay(date), 6 - dayIndex)
    }

    private static func daysBetween(start: Date, end: Date) -> Int {
        let safeStart = startOfDay(start)
        let safeEnd = startOfDay(end)
        return calendar.dateComponents([.day], from: safeStart, to: safeEnd).day ?? 0
    }

    private static func intersectsRange(startA: Date, endA: Date, startB: Date, endB: Date) -> Bool {
        startA <= endB && endA >= startB
    }

    private static func isShortEvent(_ event: CalendarEvent) -> Bool {
        event.end.timeIntervalSince(event.start) < daySeconds
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM yyyy HH:mm"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "LLLL"
        return formatter
    }()

    private static let monthShortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "LLL"
        return formatter
    }()
}
