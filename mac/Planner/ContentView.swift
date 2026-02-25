import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var viewModel: PlannerViewModel

    private var weeks: [[Date]] {
        YearLayout.buildYearWeeks(year: viewModel.calendarYear)
    }

    private var monthStartLabels: [String: MonthStartLabel] {
        YearLayout.buildMonthStartLabels(weeks: weeks)
    }

    private var weekRenderData: [WeekRenderData] {
        weeks.map { YearLayout.buildWeekRenderData(week: $0, events: viewModel.events) }
    }

    private var todayKey: String {
        YearLayout.formatDateKey(Date())
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color(red: 0.96, green: 0.97, blue: 0.94)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                        .padding(.bottom, 4)

                    stateMessages
                        .padding(.horizontal, 10)
                        .padding(.bottom, 4)

                    Divider()
                        .overlay(Color.black.opacity(0.10))

                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            Section {
                                ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                                    WeekRowView(
                                        week: week,
                                        weekData: weekRenderData[index],
                                        calendarYear: viewModel.calendarYear,
                                        todayKey: todayKey,
                                        monthStartLabels: monthStartLabels,
                                        onTapEvent: { event in
                                            viewModel.openEventDetails(event)
                                        }
                                    )
                                    .overlay(alignment: .bottom) {
                                        Rectangle()
                                            .fill(Color.black.opacity(0.08))
                                            .frame(height: 0.5)
                                    }
                                }
                            } header: {
                                WeekdayHeaderView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .sheet(item: $viewModel.selectedEvent) { event in
            EventDetailsSheet(event: event) {
                viewModel.closeEventDetails()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("The Planner")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.30, blue: 0.24))
                        .textCase(.uppercase)
                    Text("sha-\(appVersionTag)")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.45))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    headerButton(systemName: "chevron.left") {
                        viewModel.moveToPreviousYear()
                    }

                    Text(formattedYear)
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(Color(red: 0.11, green: 0.14, blue: 0.10))
                        .onTapGesture(count: 2) {
                            viewModel.jumpToCurrentYear()
                        }

                    headerButton(systemName: "chevron.right") {
                        viewModel.moveToNextYear()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Group {
                    if viewModel.authStatus == .authenticated {
                        Button {
                            viewModel.signOut()
                        } label: {
                            HStack(spacing: 6) {
                                profileAvatar(url: viewModel.profilePictureURL)
                                Text(viewModel.userLabel)
                                    .lineLimit(1)
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 6)
                            .frame(height: 34)
                            .background(Color.white.opacity(0.85), in: Capsule())
                            .overlay(
                                Capsule().stroke(Color.black.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            viewModel.signIn()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                Text(viewModel.authStatus == .loading ? "Signing in..." : "Sign in")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 10)
                            .frame(height: 36)
                            .background(Color.white.opacity(0.85), in: Capsule())
                            .overlay(
                                Capsule().stroke(Color.black.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if viewModel.authStatus != .authenticated {
                Text("Sign in with Google to load your calendar events.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.black.opacity(0.50))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var stateMessages: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let authError = viewModel.authError, !authError.isEmpty {
                Text(authError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            if let fetchError = viewModel.fetchError, !fetchError.isEmpty {
                Text(fetchError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            if viewModel.loadingEvents {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Loading events...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headerButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 24, height: 24)
                .background(.white.opacity(0.75), in: Circle())
                .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func profileAvatar(url: URL?) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(1)
                        .foregroundStyle(Color.black.opacity(0.55))
                }
            }
            .frame(width: 16, height: 16)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.black.opacity(0.10), lineWidth: 0.5))
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color.black.opacity(0.55))
        }
    }

    private var appVersionTag: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "v\(version)"
    }

    private var formattedYear: String {
        "\(viewModel.calendarYear)"
    }
}

private struct WeekdayHeaderView: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(WEEKDAYS.enumerated()), id: \.offset) { index, weekday in
                Text(weekday)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.22, green: 0.28, blue: 0.22))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(index >= 5 ? Color(red: 0.84, green: 0.89, blue: 0.83).opacity(0.85) : .clear)
            }
        }
        .background(Color(red: 0.84, green: 0.89, blue: 0.83).opacity(0.95))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.12)).frame(height: 0.5)
        }
    }
}

private struct WeekRowView: View {
    let week: [Date]
    let weekData: WeekRenderData
    let calendarYear: Int
    let todayKey: String
    let monthStartLabels: [String: MonthStartLabel]
    let onTapEvent: (CalendarEvent) -> Void

    private var monthStartIndex: Int {
        week.firstIndex(where: { monthStartLabels[YearLayout.formatDateKey($0)] != nil }) ?? -1
    }

    private var barsTop: CGFloat {
        monthStartIndex >= 0 ? 26 : 22
    }

    private let rowHeight: CGFloat = 90

    var body: some View {
        GeometryReader { geometry in
            let cellWidth = geometry.size.width / 7

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let date = week[dayIndex]
                        let key = YearLayout.formatDateKey(date)

                        DayCellView(
                            date: date,
                            dayIndex: dayIndex,
                            calendarYear: calendarYear,
                            isToday: key == todayKey,
                            monthLabel: monthStartLabels[key],
                            activeBarsCount: weekData.activeBarsByDateKey[key] ?? 0,
                            shortEvents: weekData.shortEventsByDateKey[key] ?? [],
                            overflowBars: weekData.overflowBarsByDateKey[key] ?? 0,
                            barsTop: barsTop,
                            onTapEvent: onTapEvent
                        )
                        .frame(width: cellWidth, height: rowHeight)
                    }
                }

                ForEach(weekData.weekBars) { bar in
                    let span = bar.endIdx - bar.startIdx + 1

                    Button {
                        onTapEvent(bar.event)
                    } label: {
                        ZStack(alignment: .leading) {
                            SelectiveRoundedRectangle(radius: 8, corners: corners(for: bar))
                                .fill(Color(hex: bar.event.color, fallback: Color(red: 0.30, green: 0.54, blue: 0.41)))

                            Text(bar.event.summary)
                                .font(.system(size: 9, weight: .semibold))
                                .lineLimit(1)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: max(8, CGFloat(span) * cellWidth - 2), height: 16)
                    .offset(
                        x: CGFloat(bar.startIdx) * cellWidth + 1,
                        y: barsTop + laneOffset(for: bar.lane)
                    )
                }
            }
        }
        .frame(height: rowHeight)
    }

    private func laneOffset(for lane: Int) -> CGFloat {
        switch lane {
        case 0: return 0
        case 1: return 18
        default: return 36
        }
    }

    private func corners(for bar: WeekBar) -> UIRectCorner {
        var result: UIRectCorner = []
        if !bar.continuesFromPreviousWeek {
            result.formUnion([.topLeft, .bottomLeft])
        }
        if !bar.continuesToNextWeek {
            result.formUnion([.topRight, .bottomRight])
        }
        return result
    }
}

private struct DayCellView: View {
    let date: Date
    let dayIndex: Int
    let calendarYear: Int
    let isToday: Bool
    let monthLabel: MonthStartLabel?
    let activeBarsCount: Int
    let shortEvents: [CalendarEvent]
    let overflowBars: Int
    let barsTop: CGFloat
    let onTapEvent: (CalendarEvent) -> Void

    private var dateKey: String {
        YearLayout.formatDateKey(date)
    }

    private var isCurrentYear: Bool {
        Calendar.current.component(.year, from: date) == calendarYear
    }

    private var timedEventsOffset: CGFloat {
        if activeBarsCount >= 3 {
            return 42
        }
        if activeBarsCount == 2 {
            return 30
        }
        if activeBarsCount == 1 {
            return 18
        }
        return 6
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(dayIndex >= 5 ? Color(red: 0.93, green: 0.95, blue: 0.92) : Color(red: 0.97, green: 0.97, blue: 0.96))

            leftBorder

            if let monthLabel {
                Text(monthLabel.short.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.23, green: 0.25, blue: 0.22))
                    .padding(.leading, 4)
                    .padding(.top, 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Spacer().frame(height: barsTop + timedEventsOffset)

                if overflowBars > 0 {
                    Text("+\(overflowBars) more")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(shortEvents.prefix(MAX_VISIBLE_TIMED)), id: \.id) { event in
                    Button {
                        onTapEvent(event)
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: event.color, fallback: Color(red: 0.30, green: 0.54, blue: 0.41)))
                                .frame(width: 6, height: 6)

                            Text("\(YearLayout.formatEventTime(event.start)) \(event.summary)")
                                .font(.system(size: 8))
                                .lineLimit(1)
                                .foregroundStyle(Color(red: 0.27, green: 0.30, blue: 0.25))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)

            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .foregroundStyle(isToday ? .white : (isCurrentYear ? Color(red: 0.34, green: 0.37, blue: 0.33) : Color.black.opacity(0.35)))
                .frame(minWidth: 18, minHeight: 18)
                .background(
                    Circle().fill(isToday ? Color.black.opacity(0.8) : .clear)
                )
                .padding(.top, 2)
                .padding(.trailing, 3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(dateKey)")
    }

    @ViewBuilder
    private var leftBorder: some View {
        let isMonthStart = monthLabel != nil

        if isMonthStart {
            Rectangle()
                .fill(Color.black.opacity(0.75))
                .frame(width: 2.5)
                .frame(maxHeight: .infinity, alignment: .leading)
        } else if dayIndex > 0 {
            Rectangle()
                .fill(Color.black.opacity(0.07))
                .frame(width: 0.5)
                .frame(maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct EventDetailsSheet: View {
    let event: CalendarEvent
    let onClose: () -> Void

    private var rangeLabel: String {
        if event.isAllDay {
            if Calendar.current.isDate(event.start, inSameDayAs: event.end) {
                return "\(dateLabel(event.start)) (all day)"
            }
            return "\(dateLabel(event.start)) - \(dateLabel(event.end)) (all day)"
        }

        if Calendar.current.isDate(event.start, inSameDayAs: event.end) {
            return "\(dateLabel(event.start)) · \(timeLabel(event.start)) - \(timeLabel(event.end))"
        }

        return "\(dateLabel(event.start)) \(timeLabel(event.start)) - \(dateLabel(event.end)) \(timeLabel(event.end))"
    }

    private var links: [URL] {
        extractURLs(from: event.description)
    }

    private var mapURL: URL? {
        let trimmedLocation = event.location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLocation.isEmpty else {
            return nil
        }

        var components = URLComponents(string: "https://www.google.com/maps/search/")!
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: trimmedLocation)
        ]

        return components.url
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: event.color, fallback: Color(red: 0.30, green: 0.54, blue: 0.41)))
                            .frame(width: 10, height: 10)

                        Text("Event")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(event.summary)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.14, green: 0.18, blue: 0.12))

                    detailRow(label: "When", value: rangeLabel)
                    if let mapURL {
                        detailRowLink(label: "Where", value: event.location.trimmingCharacters(in: .whitespacesAndNewlines), destination: mapURL)
                    } else {
                        detailRow(label: "Where", value: event.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No location" : event.location)
                    }

                    if let status = event.status, !status.isEmpty {
                        detailRow(label: "Status", value: status.capitalized)
                    }

                    if !event.isAutomaticallyCreated {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Text(event.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No description" : event.description)
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.20, green: 0.24, blue: 0.18))
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(red: 0.95, green: 0.97, blue: 0.94), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        if !links.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Links")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                ForEach(links, id: \.absoluteString) { link in
                                    Link(destination: link) {
                                        Text(link.absoluteString)
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color(red: 0.15, green: 0.40, blue: 0.26))
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }

                    if event.calendarURL != nil || event.originalEmailURL != nil {
                        HStack(spacing: 8) {
                            if let calendarURL = event.calendarURL {
                                Link(destination: calendarURL) {
                                    Text("Open in Calendar")
                                        .font(.system(size: 13, weight: .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(red: 0.86, green: 0.92, blue: 0.84), in: Capsule())
                                }
                            }

                            if let originalEmailURL = event.originalEmailURL {
                                Link(destination: originalEmailURL) {
                                    Text("Original Email")
                                        .font(.system(size: 13, weight: .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(red: 0.86, green: 0.92, blue: 0.84), in: Capsule())
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.85), in: Circle())
                            .overlay(Circle().stroke(Color.black.opacity(0.10), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 0.20, green: 0.24, blue: 0.18))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailRowLink(label: String, value: String, destination: URL) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            Link(destination: destination) {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.15, green: 0.40, blue: 0.26))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dateLabel(_ date: Date) -> String {
        EventDetailsSheet.dateFormatter.string(from: date)
    }

    private func timeLabel(_ date: Date) -> String {
        EventDetailsSheet.timeFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEE, MMM d, yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct SelectiveRoundedRectangle: Shape {
    let radius: CGFloat
    let corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let safeCorners: UIRectCorner = corners.isEmpty
            ? [.topLeft, .topRight, .bottomLeft, .bottomRight]
            : corners

        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: safeCorners,
            cornerRadii: CGSize(width: radius, height: radius)
        )

        return Path(path.cgPath)
    }
}

private extension Color {
    init(hex: String, fallback: Color) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        let expanded: String
        switch sanitized.count {
        case 3, 4:
            expanded = sanitized.map { "\($0)\($0)" }.joined()
        case 6:
            expanded = sanitized + "ff"
        case 8:
            expanded = sanitized
        default:
            self = fallback
            return
        }

        guard let value = UInt64(expanded, radix: 16) else {
            self = fallback
            return
        }

        let red = Double((value >> 24) & 0xff) / 255.0
        let green = Double((value >> 16) & 0xff) / 255.0
        let blue = Double((value >> 8) & 0xff) / 255.0
        let alpha = Double(value & 0xff) / 255.0

        self = Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

private func extractURLs(from text: String) -> [URL] {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
        return []
    }

    let range = NSRange(location: 0, length: text.utf16.count)
    let matches = detector.matches(in: text, options: [], range: range)

    var seen: Set<String> = []
    var urls: [URL] = []

    for match in matches {
        guard let url = match.url else {
            continue
        }

        if seen.contains(url.absoluteString) {
            continue
        }

        seen.insert(url.absoluteString)
        urls.append(url)
    }

    return urls
}

#Preview {
    ContentView()
        .environmentObject(PlannerViewModel())
}
