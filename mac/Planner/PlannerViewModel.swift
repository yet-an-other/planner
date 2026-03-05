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

    @Published var authStatus: AuthStatus = .unauthenticated
    @Published var authError: String?
    @Published var fetchError: String?
    @Published var loadingEvents = false
    @Published var profile: GoogleUserProfile?
    @Published var events: [CalendarEvent] = []
    @Published var selectedEvent: CalendarEvent?
    @Published var calendarYear: Int = Calendar.current.component(.year, from: Date())

    private static let autoRefreshIntervalSeconds: UInt64 = 60

    private var session: GoogleAuthSession?
    private let oauthService = GoogleOAuthService()
    private let calendarService = GoogleCalendarService()
    private let authStore = PersistedAuthStore()
    private var appIsActive = true
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var autoRefreshTask: Task<Void, Never>?

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
        guard session != nil, !loadingEvents else {
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
            authStore.saveSession(nextSession)
            authStore.saveProfile(nextProfile)
            authStatus = .authenticated
            startAutoRefreshIfNeeded()
            await loadEvents()
        } catch {
            clearAuthenticationState(
                errorMessage: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }
    }

    private func loadEvents() async {
        guard session != nil else {
            events = []
            loadingEvents = false
            return
        }

        loadingEvents = true
        fetchError = nil

        do {
            let activeSession = try await sessionForCalendarRequests()
            let fetched = try await calendarService.getEventsForYear(
                year: calendarYear,
                accessToken: activeSession.accessToken,
                calendarID: GoogleConfig.calendarID
            )
            events = fetched
            loadingEvents = false
        } catch CalendarError.sessionExpired {
            await retryLoadEventsAfterUnauthorized()
        } catch {
            loadingEvents = false
            events = []
            if error is SessionPersistenceError || error is OAuthError {
                clearAuthenticationState(
                    errorMessage: (error as? LocalizedError)?.errorDescription ?? "Google session expired. Please sign in again."
                )
            } else {
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
            await loadEvents()
        } catch {
            clearAuthenticationState(errorMessage: nil)
        }
    }

    private func retryLoadEventsAfterUnauthorized() async {
        do {
            let refreshedSession = try await sessionForCalendarRequests(forceRefresh: true)
            let fetched = try await calendarService.getEventsForYear(
                year: calendarYear,
                accessToken: refreshedSession.accessToken,
                calendarID: GoogleConfig.calendarID
            )
            events = fetched
            loadingEvents = false
            fetchError = nil
        } catch {
            loadingEvents = false
            events = []
            clearAuthenticationState(
                errorMessage: (error as? LocalizedError)?.errorDescription ?? "Google session expired. Please sign in again."
            )
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
        authStore.clear()
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

        await loadEvents()
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

    func clear() {
        UserDefaults.standard.removeObject(forKey: profileKey)
        SecItemDelete(keychainBaseQuery as CFDictionary)
    }

    private var keychainBaseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
    }
}
