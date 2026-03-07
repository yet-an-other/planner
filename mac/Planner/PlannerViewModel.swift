import Foundation
import Security
import UIKit

@MainActor
final class PlannerViewModel: ObservableObject {
    enum AuthStatus {
        case loading
        case authenticated
        case unauthenticated
    }

    enum RefreshState {
        case unknown
        case success
        case offline
    }

    @Published var authStatus: AuthStatus = .unauthenticated
    @Published var authError: String?
    @Published var fetchError: String?
    @Published var loadingEvents = false
    @Published var profile: GoogleUserProfile?
    @Published var events: [CalendarEvent] = []
    @Published var selectedEvent: CalendarEvent?
    @Published var calendarYear: Int = Calendar.current.component(.year, from: Date())
    @Published var refreshState: RefreshState = .unknown
    @Published var lastSuccessfulRefreshAt: Date?

    private static let autoRefreshIntervalSeconds: UInt64 = 60

    private var session: GoogleAuthSession?
    private let oauthService = GoogleOAuthService()
    private let calendarService = GoogleCalendarService()
    private let authStore = PersistedAuthStore()
    private var appIsActive = true
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var autoRefreshTask: Task<Void, Never>?
    private var requestedLoadYear: Int?
    private var processingRequestedLoads = false

    init() {
        configureLifecycleObservers()
        Task {
            await restorePersistedAuthentication()
        }
    }

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
            clearAuthenticationState(errorMessage: nil)
            await oauthService.signOut(session: currentSession)
        }
    }

    func loadEventsIfAuthenticated() {
        guard session != nil else {
            return
        }
        requestEventsLoad(forYear: calendarYear)
    }

    private func performSignIn() async {
        authStatus = .loading
        authError = nil
        refreshState = .unknown

        do {
            let nextSession = try await oauthService.signIn()
            let nextProfile = try await oauthService.fetchUserProfile(session: nextSession)

            session = nextSession
            profile = nextProfile
            authStore.saveSession(nextSession)
            authStore.saveProfile(nextProfile)
            authStatus = .authenticated
            startAutoRefreshIfNeeded()
            requestEventsLoad(forYear: calendarYear)
        } catch {
            clearAuthenticationState(
                errorMessage: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }
    }

    private func requestEventsLoad(forYear year: Int) {
        requestedLoadYear = year
        applyVisibleEventsSnapshot(forYear: year)

        guard !processingRequestedLoads else {
            return
        }

        Task {
            await processRequestedLoads()
        }
    }

    private func processRequestedLoads() async {
        guard !processingRequestedLoads else {
            return
        }

        processingRequestedLoads = true
        loadingEvents = true
        defer {
            processingRequestedLoads = false
            loadingEvents = false
        }

        while let year = requestedLoadYear, session != nil {
            requestedLoadYear = nil
            await loadEvents(forYear: year)
        }
    }

    private func loadEvents(forYear year: Int) async {
        guard session != nil else {
            events = []
            return
        }

        do {
            let activeSession = try await sessionForCalendarRequests()
            let fetched = try await calendarService.getEventsForYear(
                year: year,
                accessToken: activeSession.accessToken,
                calendarID: GoogleConfig.calendarID
            )
            authStore.saveEvents(fetched, forYear: year)
            if shouldApplyLoadResult(forYear: year) {
                events = fetched
                fetchError = nil
            }
            markRefreshSuccess()
        } catch CalendarError.sessionExpired {
            await retryLoadEventsAfterUnauthorized(forYear: year)
        } catch {
            if error is SessionPersistenceError || error is OAuthError {
                clearAuthenticationState(
                    errorMessage: (error as? LocalizedError)?.errorDescription ?? "Google session expired. Please sign in again."
                )
            } else if isOfflineError(error) {
                if shouldApplyLoadResult(forYear: year) {
                    applyOfflineFallback(forYear: year)
                }
            } else if shouldApplyLoadResult(forYear: year) {
                fetchError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func restorePersistedAuthentication() async {
        guard let savedSession = authStore.loadSession() else {
            return
        }

        authStatus = .loading
        authError = nil
        fetchError = nil
        session = savedSession
        profile = authStore.loadProfile()
        lastSuccessfulRefreshAt = authStore.loadLastSuccessfulRefresh()
        refreshState = lastSuccessfulRefreshAt == nil ? .unknown : .success

        if let cachedEvents = authStore.loadEvents(forYear: calendarYear) {
            events = cachedEvents
        }

        do {
            let activeSession = try await sessionForCalendarRequests()
            if profile == nil {
                if let fetchedProfile = try? await oauthService.fetchUserProfile(session: activeSession) {
                    profile = fetchedProfile
                    authStore.saveProfile(fetchedProfile)
                }
            }

            authStatus = .authenticated
            startAutoRefreshIfNeeded()
            requestEventsLoad(forYear: calendarYear)
        } catch {
            if isOfflineError(error) {
                authStatus = .authenticated
                refreshState = .offline
                startAutoRefreshIfNeeded()
                if let cachedEvents = authStore.loadEvents(forYear: calendarYear) {
                    events = cachedEvents
                } else {
                    events = []
                }
            } else {
                clearAuthenticationState(errorMessage: nil)
            }
        }
    }

    private func retryLoadEventsAfterUnauthorized(forYear year: Int) async {
        do {
            let refreshedSession = try await sessionForCalendarRequests(forceRefresh: true)
            let fetched = try await calendarService.getEventsForYear(
                year: year,
                accessToken: refreshedSession.accessToken,
                calendarID: GoogleConfig.calendarID
            )
            authStore.saveEvents(fetched, forYear: year)
            if shouldApplyLoadResult(forYear: year) {
                events = fetched
                fetchError = nil
            }
            markRefreshSuccess()
        } catch {
            if isOfflineError(error) {
                if shouldApplyLoadResult(forYear: year) {
                    applyOfflineFallback(forYear: year)
                }
            } else if shouldApplyLoadResult(forYear: year) {
                clearAuthenticationState(
                    errorMessage: (error as? LocalizedError)?.errorDescription ?? "Google session expired. Please sign in again."
                )
            }
        }
    }

    private func sessionForCalendarRequests(forceRefresh: Bool = false) async throws -> GoogleAuthSession {
        guard let activeSession = session else {
            throw SessionPersistenceError.missingSession
        }

        if !forceRefresh, activeSession.expiresAt > Date() {
            return activeSession
        }

        return try await refreshSession()
    }

    private func refreshSession() async throws -> GoogleAuthSession {
        guard let currentSession = session else {
            throw SessionPersistenceError.missingSession
        }

        guard let refreshToken = currentSession.refreshToken, !refreshToken.isEmpty else {
            throw SessionPersistenceError.missingRefreshToken
        }

        let refreshedSession = try await oauthService.refreshSession(refreshToken: refreshToken)
        session = refreshedSession
        authStore.saveSession(refreshedSession)
        return refreshedSession
    }

    private func clearAuthenticationState(errorMessage: String?) {
        stopAutoRefresh()
        session = nil
        profile = nil
        events = []
        loadingEvents = false
        fetchError = nil
        authError = errorMessage
        authStatus = .unauthenticated
        refreshState = .unknown
        lastSuccessfulRefreshAt = nil
        authStore.clear()
    }

    private func markRefreshSuccess() {
        let refreshDate = Date()
        lastSuccessfulRefreshAt = refreshDate
        refreshState = .success
        authStore.saveLastSuccessfulRefresh(refreshDate)
    }

    private func applyVisibleEventsSnapshot(forYear year: Int) {
        events = authStore.loadEvents(forYear: year) ?? []
        fetchError = nil
    }

    private func shouldApplyLoadResult(forYear year: Int) -> Bool {
        calendarYear == year
    }

    private func applyOfflineFallback(forYear year: Int) {
        let cachedEvents = authStore.loadEvents(forYear: year) ?? []
        events = cachedEvents
        refreshState = .offline
        if cachedEvents.isEmpty {
            fetchError = "Offline. No cached events are available for this year."
        } else {
            fetchError = "Offline. Showing last loaded events."
        }
    }

    private func isOfflineError(_ error: Error) -> Bool {
        let offlineCodes: Set<URLError.Code> = [
            .notConnectedToInternet,
            .networkConnectionLost,
            .cannotConnectToHost,
            .cannotFindHost,
            .dnsLookupFailed,
            .timedOut,
            .internationalRoamingOff,
            .callIsActive,
            .dataNotAllowed
        ]

        if let urlError = error as? URLError {
            return offlineCodes.contains(urlError.code)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let code = URLError.Code(rawValue: nsError.code)
            return offlineCodes.contains(code)
        }

        return false
    }

    private func configureLifecycleObservers() {
        let center = NotificationCenter.default

        let didBecomeActive = center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }

            Task { @MainActor in
                self.appIsActive = true
                self.startAutoRefreshIfNeeded()
                self.loadEventsIfAuthenticated()
            }
        }

        let didEnterBackground = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }

            Task { @MainActor in
                self.appIsActive = false
                self.stopAutoRefresh()
            }
        }

        lifecycleObservers = [didBecomeActive, didEnterBackground]
    }

    private func startAutoRefreshIfNeeded() {
        guard appIsActive, authStatus == .authenticated else {
            return
        }

        guard autoRefreshTask == nil else {
            return
        }

        autoRefreshTask = Task { [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: Self.autoRefreshIntervalSeconds * 1_000_000_000)
                } catch {
                    return
                }

                guard !Task.isCancelled else {
                    return
                }

                await self.performAutoRefreshTick()
            }
        }
    }

    private func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    private func performAutoRefreshTick() async {
        guard appIsActive, authStatus == .authenticated, !loadingEvents else {
            return
        }

        requestEventsLoad(forYear: calendarYear)
    }
}

private enum SessionPersistenceError: LocalizedError {
    case missingSession
    case missingRefreshToken

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "Google session is missing. Please sign in again."
        case .missingRefreshToken:
            return "Google session expired. Please sign in again."
        }
    }
}

private struct PersistedAuthStore {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let profileKey = "planner.google.user.profile"
    private let eventsByYearKey = "planner.google.events.byYear"
    private let lastSuccessfulRefreshKey = "planner.google.events.lastSuccessfulRefresh"
    private let keychainService = Bundle.main.bundleIdentifier.map { "\($0).auth" } ?? "planner.auth"
    private let keychainAccount = "google.auth.session"

    func saveSession(_ session: GoogleAuthSession) {
        guard let data = try? encoder.encode(session) else {
            return
        }

        let query = keychainBaseQuery
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        if status == errSecItemNotFound {
            var insertQuery = query
            insertQuery[kSecValueData as String] = data
            insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(insertQuery as CFDictionary, nil)
        }
    }

    func loadSession() -> GoogleAuthSession? {
        var query = keychainBaseQuery
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        return try? decoder.decode(GoogleAuthSession.self, from: data)
    }

    func saveProfile(_ profile: GoogleUserProfile) {
        guard let data = try? encoder.encode(profile) else {
            return
        }

        UserDefaults.standard.set(data, forKey: profileKey)
    }

    func loadProfile() -> GoogleUserProfile? {
        guard let data = UserDefaults.standard.data(forKey: profileKey) else {
            return nil
        }

        return try? decoder.decode(GoogleUserProfile.self, from: data)
    }

    func saveEvents(_ events: [CalendarEvent], forYear year: Int) {
        var cache = loadEventsByYear()
        cache[String(year)] = events

        guard let data = try? encoder.encode(cache) else {
            return
        }

        UserDefaults.standard.set(data, forKey: eventsByYearKey)
    }

    func loadEvents(forYear year: Int) -> [CalendarEvent]? {
        loadEventsByYear()[String(year)]
    }

    func saveLastSuccessfulRefresh(_ value: Date) {
        UserDefaults.standard.set(value, forKey: lastSuccessfulRefreshKey)
    }

    func loadLastSuccessfulRefresh() -> Date? {
        UserDefaults.standard.object(forKey: lastSuccessfulRefreshKey) as? Date
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: profileKey)
        UserDefaults.standard.removeObject(forKey: eventsByYearKey)
        UserDefaults.standard.removeObject(forKey: lastSuccessfulRefreshKey)
        SecItemDelete(keychainBaseQuery as CFDictionary)
    }

    private func loadEventsByYear() -> [String: [CalendarEvent]] {
        guard let data = UserDefaults.standard.data(forKey: eventsByYearKey),
              let decoded = try? decoder.decode([String: [CalendarEvent]].self, from: data) else {
            return [:]
        }

        return decoded
    }

    private var keychainBaseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
    }
}
