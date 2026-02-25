import Foundation

@MainActor
final class PlannerViewModel: ObservableObject {
    enum AuthStatus {
        case loading
        case authenticated
        case unauthenticated
    }

    @Published var authStatus: AuthStatus = .unauthenticated
    @Published var authError: String?
    @Published var fetchError: String?
    @Published var loadingEvents = false
    @Published var profile: GoogleUserProfile?
    @Published var events: [CalendarEvent] = []
    @Published var selectedEvent: CalendarEvent?
    @Published var calendarYear: Int = Calendar.current.component(.year, from: Date())

    private var session: GoogleAuthSession?
    private let oauthService = GoogleOAuthService()
    private let calendarService = GoogleCalendarService()

    var userLabel: String {
        profile?.name ?? profile?.email ?? "Google account"
    }

    var profilePictureURL: URL? {
        profile?.picture
    }

    func openEventDetails(_ event: CalendarEvent) {
        selectedEvent = event
    }

    func closeEventDetails() {
        selectedEvent = nil
    }

    func moveToPreviousYear() {
        calendarYear = max(1, calendarYear - 1)
        loadEventsIfAuthenticated()
    }

    func moveToNextYear() {
        calendarYear = min(9999, calendarYear + 1)
        loadEventsIfAuthenticated()
    }

    func jumpToCurrentYear() {
        calendarYear = Calendar.current.component(.year, from: Date())
        loadEventsIfAuthenticated()
    }

    func signIn() {
        Task {
            await performSignIn()
        }
    }

    func signOut() {
        Task {
            let currentSession = session
            session = nil
            profile = nil
            events = []
            loadingEvents = false
            fetchError = nil
            authError = nil
            authStatus = .unauthenticated
            await oauthService.signOut(session: currentSession)
        }
    }

    func loadEventsIfAuthenticated() {
        guard session != nil else {
            return
        }

        Task {
            await loadEvents()
        }
    }

    private func performSignIn() async {
        authStatus = .loading
        authError = nil

        do {
            let nextSession = try await oauthService.signIn()
            let nextProfile = try await oauthService.fetchUserProfile(session: nextSession)

            session = nextSession
            profile = nextProfile
            authStatus = .authenticated
            await loadEvents()
        } catch {
            session = nil
            profile = nil
            authStatus = .unauthenticated
            authError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func loadEvents() async {
        guard let activeSession = session else {
            events = []
            loadingEvents = false
            return
        }

        loadingEvents = true
        fetchError = nil

        do {
            let fetched = try await calendarService.getEventsForYear(
                year: calendarYear,
                accessToken: activeSession.accessToken,
                calendarID: GoogleConfig.calendarID
            )
            events = fetched
            loadingEvents = false
        } catch {
            loadingEvents = false
            events = []
            fetchError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
