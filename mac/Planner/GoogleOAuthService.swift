import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

private let oauthEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
private let tokenEndpoint = "https://oauth2.googleapis.com/token"
private let userInfoEndpoint = "https://openidconnect.googleapis.com/v1/userinfo"
private let revokeEndpoint = "https://oauth2.googleapis.com/revoke"

private let oauthScopes = [
    "openid",
    "profile",
    "email",
    "https://www.googleapis.com/auth/calendar.readonly"
].joined(separator: " ")

struct GoogleAuthSession {
    let accessToken: String
    let tokenType: String
    let scope: String
    let expiresAt: Date
}

struct GoogleUserProfile {
    let id: String
    let email: String?
    let name: String?
    let picture: URL?
}

enum GoogleConfig {
    static var clientID: String {
        infoValue("GOOGLE_CLIENT_ID")
    }

    static var redirectURI: String {
        infoValue("GOOGLE_OAUTH_REDIRECT_URI")
    }

    static var calendarID: String {
        let value = infoValue("GOOGLE_CALENDAR_ID")
        return value.isEmpty ? "primary" : value
    }

    static var callbackScheme: String {
        guard let url = URL(string: redirectURI),
              let scheme = url.scheme else {
            return ""
        }

        return scheme
    }

    static func validate() throws {
        if clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw OAuthError.configuration("Set GOOGLE_CLIENT_ID in Planner/Info.plist.")
        }

        if redirectURI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw OAuthError.configuration("Set GOOGLE_OAUTH_REDIRECT_URI in Planner/Info.plist.")
        }

        if callbackScheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw OAuthError.configuration("GOOGLE_OAUTH_REDIRECT_URI must include a custom URL scheme.")
        }
    }

    private static func infoValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}

final class GoogleOAuthService {
    private let presentationContextProvider = OAuthPresentationContextProvider()
    private var activeSession: ASWebAuthenticationSession?

    func signIn() async throws -> GoogleAuthSession {
        try GoogleConfig.validate()

        let state = Self.randomURLSafeString(length: 32)
        let codeVerifier = Self.randomURLSafeString(length: 64)
        let codeChallenge = Self.pkceChallenge(from: codeVerifier)

        var components = URLComponents(string: oauthEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: GoogleConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: oauthScopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "select_account"),
            URLQueryItem(name: "include_granted_scopes", value: "true"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authorizationURL = components.url else {
            throw OAuthError.configuration("Google OAuth URL could not be created.")
        }

        let callbackURL = try await startWebAuthentication(url: authorizationURL, expectedState: state)
        guard let code = Self.queryValue(name: "code", in: callbackURL) else {
            if let oauthError = Self.queryValue(name: "error", in: callbackURL) {
                throw OAuthError.signInFailed("Google sign-in failed: \(oauthError.replacingOccurrences(of: "_", with: " ")).")
            }
            throw OAuthError.signInFailed("Google sign-in did not return an authorization code.")
        }

        return try await exchangeCodeForToken(code: code, codeVerifier: codeVerifier)
    }

    func fetchUserProfile(session: GoogleAuthSession) async throws -> GoogleUserProfile {
        guard let url = URL(string: userInfoEndpoint) else {
            throw OAuthError.configuration("User profile endpoint URL is invalid.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.network("Could not read Google profile response.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw OAuthError.network("Google profile request failed (\(httpResponse.statusCode)).")
        }

        let payload = try JSONDecoder().decode(GoogleUserInfoResponse.self, from: data)
        return GoogleUserProfile(
            id: payload.sub ?? "",
            email: payload.email,
            name: payload.name,
            picture: URL(string: payload.picture ?? "")
        )
    }

    func signOut(session: GoogleAuthSession?) async {
        guard let session,
              let url = URL(string: "\(revokeEndpoint)?token=\(session.accessToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? session.accessToken)") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        _ = try? await URLSession.shared.data(for: request)
    }

    private func startWebAuthentication(url: URL, expectedState: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let callbackScheme = GoogleConfig.callbackScheme

            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
                self?.activeSession = nil

                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: OAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: OAuthError.signInFailed("Google sign-in returned no callback URL."))
                    return
                }

                guard let returnedState = Self.queryValue(name: "state", in: callbackURL),
                      returnedState == expectedState else {
                    continuation.resume(throwing: OAuthError.signInFailed("Google sign-in failed: invalid OAuth state."))
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = presentationContextProvider
            session.prefersEphemeralWebBrowserSession = false
            self.activeSession = session

            if !session.start() {
                self.activeSession = nil
                continuation.resume(throwing: OAuthError.signInFailed("Could not start Google sign-in."))
            }
        }
    }

    private func exchangeCodeForToken(code: String, codeVerifier: String) async throws -> GoogleAuthSession {
        guard let url = URL(string: tokenEndpoint) else {
            throw OAuthError.configuration("Google token endpoint URL is invalid.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyItems = [
            URLQueryItem(name: "client_id", value: GoogleConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: GoogleConfig.redirectURI),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: codeVerifier)
        ]

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = bodyItems
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.network("Could not read Google token response.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw OAuthError.network("Google token exchange failed (\(httpResponse.statusCode)). \(message)")
        }

        let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let accessToken = payload.accessToken,
              let expiresIn = payload.expiresIn,
              expiresIn > 0 else {
            throw OAuthError.network("Google token response was incomplete.")
        }

        return GoogleAuthSession(
            accessToken: accessToken,
            tokenType: payload.tokenType ?? "Bearer",
            scope: payload.scope ?? oauthScopes,
            expiresAt: Date().addingTimeInterval(TimeInterval(max(1, expiresIn - 30)))
        )
    }

    private static func pkceChallenge(from verifier: String) -> String {
        let hashed = SHA256.hash(data: Data(verifier.utf8))
        return Data(hashed).base64URLEncodedString()
    }

    private static func randomURLSafeString(length: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func queryValue(name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}

enum OAuthError: LocalizedError {
    case configuration(String)
    case signInFailed(String)
    case network(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .configuration(let message), .signInFailed(let message), .network(let message):
            return message
        case .cancelled:
            return "Sign-in was cancelled."
        }
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String?
    let expiresIn: Int?
    let tokenType: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }
}

private struct GoogleUserInfoResponse: Decodable {
    let sub: String?
    let email: String?
    let name: String?
    let picture: String?
}

private final class OAuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
