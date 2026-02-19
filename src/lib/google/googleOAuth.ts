import type { GoogleAuthSession, GoogleOAuthEnv, GoogleUserProfile } from './googleAuth.model'

const OAUTH_ENDPOINT = 'https://accounts.google.com/o/oauth2/v2/auth'
const USER_INFO_ENDPOINT = 'https://openidconnect.googleapis.com/v1/userinfo'
const REVOKE_ENDPOINT = 'https://oauth2.googleapis.com/revoke'

const SESSION_STORAGE_KEY = 'planner.google.oauth.session'
const OAUTH_STATE_KEY = 'planner.google.oauth.state'
const OAUTH_RETURN_TO_KEY = 'planner.google.oauth.return-to'
const OAUTH_ERROR_KEY = 'planner.google.oauth.error'
const OAUTH_PROMPT_MODE_KEY = 'planner.google.oauth.prompt-mode'
const OAUTH_HAS_SIGNED_IN_KEY = 'planner.google.oauth.has-signed-in'
const OAUTH_SILENT_ATTEMPTED_KEY = 'planner.google.oauth.silent-attempted'

const OAUTH_SCOPES = [
  'openid',
  'profile',
  'email',
  'https://www.googleapis.com/auth/calendar.readonly',
].join(' ')

const SILENT_PROMPT_ERROR_CODES = new Set([
  'interaction_required',
  'login_required',
  'account_selection_required',
  'consent_required',
])

type OAuthPromptMode = 'none' | 'select_account'

type GoogleUserInfoResponse = {
  sub?: string
  email?: string
  name?: string
  picture?: string
}

function generateStateToken(): string {
  const bytes = new Uint8Array(16)
  window.crypto.getRandomValues(bytes)
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('')
}

function normalizeReturnPath(rawPath: string | null): string {
  if (!rawPath) {
    return '/'
  }

  try {
    const url = new URL(rawPath, window.location.origin)
    if (url.origin !== window.location.origin) {
      return '/'
    }

    const normalized = `${url.pathname}${url.search}`
    return normalized || '/'
  } catch {
    return '/'
  }
}

function persistAuthError(message: string): void {
  window.sessionStorage.setItem(OAUTH_ERROR_KEY, message)
}

function persistSignedInHint(): void {
  window.localStorage.setItem(OAUTH_HAS_SIGNED_IN_KEY, '1')
}

function clearSignedInHint(): void {
  window.localStorage.removeItem(OAUTH_HAS_SIGNED_IN_KEY)
}

function hasSignedInHint(): boolean {
  return window.localStorage.getItem(OAUTH_HAS_SIGNED_IN_KEY) === '1'
}

function markSilentAttempted(): void {
  window.sessionStorage.setItem(OAUTH_SILENT_ATTEMPTED_KEY, '1')
}

function clearSilentAttempted(): void {
  window.sessionStorage.removeItem(OAUTH_SILENT_ATTEMPTED_KEY)
}

function hasSilentAttemptBeenMade(): boolean {
  return window.sessionStorage.getItem(OAUTH_SILENT_ATTEMPTED_KEY) === '1'
}

function clearOAuthState(): void {
  window.sessionStorage.removeItem(OAUTH_STATE_KEY)
  window.sessionStorage.removeItem(OAUTH_PROMPT_MODE_KEY)
}

function clearPendingReturnTo(): string {
  const raw = window.sessionStorage.getItem(OAUTH_RETURN_TO_KEY)
  window.sessionStorage.removeItem(OAUTH_RETURN_TO_KEY)
  return normalizeReturnPath(raw)
}

function parseStoredSession(raw: string): GoogleAuthSession | null {
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch {
    return null
  }

  if (typeof parsed !== 'object' || parsed === null) {
    return null
  }

  const candidate = parsed as Partial<GoogleAuthSession>
  if (
    typeof candidate.accessToken !== 'string' ||
    typeof candidate.tokenType !== 'string' ||
    typeof candidate.scope !== 'string' ||
    typeof candidate.expiresAt !== 'number'
  ) {
    return null
  }

  return {
    accessToken: candidate.accessToken,
    tokenType: candidate.tokenType,
    scope: candidate.scope,
    expiresAt: candidate.expiresAt,
  }
}

function readStoredSessionRaw(): string | null {
  const raw = window.sessionStorage.getItem(SESSION_STORAGE_KEY)
  if (raw) {
    return raw
  }

  const legacyRaw = window.localStorage.getItem(SESSION_STORAGE_KEY)
  if (!legacyRaw) {
    return null
  }

  window.sessionStorage.setItem(SESSION_STORAGE_KEY, legacyRaw)
  window.localStorage.removeItem(SESSION_STORAGE_KEY)
  return legacyRaw
}

function storeSession(session: GoogleAuthSession): void {
  window.sessionStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(session))
  persistSignedInHint()
}

function clearSession(): void {
  window.sessionStorage.removeItem(SESSION_STORAGE_KEY)
  window.localStorage.removeItem(SESSION_STORAGE_KEY)
}

export function consumeGoogleOAuthRedirectIfPresent(): void {
  const hashValue = window.location.hash.startsWith('#')
    ? window.location.hash.slice(1)
    : window.location.hash
  if (!hashValue) {
    return
  }

  const params = new URLSearchParams(hashValue)
  const hasOAuthPayload = params.has('access_token') || params.has('error')
  if (!hasOAuthPayload) {
    return
  }

  const expectedState = window.sessionStorage.getItem(OAUTH_STATE_KEY)
  const returnedState = params.get('state')
  const promptMode = window.sessionStorage.getItem(OAUTH_PROMPT_MODE_KEY) as OAuthPromptMode | null
  const returnToPath = clearPendingReturnTo()
  clearOAuthState()

  const responseError = params.get('error')
  if (responseError) {
    clearSession()
    const isSilentPromptError =
      promptMode === 'none' && SILENT_PROMPT_ERROR_CODES.has(responseError)
    if (!isSilentPromptError) {
      persistAuthError(`Google sign-in failed: ${responseError.replaceAll('_', ' ')}`)
    }
    window.history.replaceState(window.history.state, '', returnToPath)
    return
  }

  if (!expectedState || !returnedState || returnedState !== expectedState) {
    clearSession()
    persistAuthError('Google sign-in failed: invalid OAuth state. Try again.')
    window.history.replaceState(window.history.state, '', returnToPath)
    return
  }

  const accessToken = params.get('access_token')
  const expiresIn = Number(params.get('expires_in') ?? '0')
  if (!accessToken || !Number.isFinite(expiresIn) || expiresIn <= 0) {
    clearSession()
    persistAuthError('Google sign-in failed: token response was incomplete.')
    window.history.replaceState(window.history.state, '', returnToPath)
    return
  }

  const session: GoogleAuthSession = {
    accessToken,
    tokenType: params.get('token_type') ?? 'Bearer',
    scope: params.get('scope') ?? OAUTH_SCOPES,
    expiresAt: Date.now() + Math.max(1, expiresIn - 30) * 1000,
  }

  storeSession(session)
  window.sessionStorage.removeItem(OAUTH_ERROR_KEY)
  clearSilentAttempted()
  window.history.replaceState(window.history.state, '', returnToPath)
}

export function consumeGoogleOAuthError(): string | null {
  const rawError = window.sessionStorage.getItem(OAUTH_ERROR_KEY)
  if (!rawError) {
    return null
  }

  window.sessionStorage.removeItem(OAUTH_ERROR_KEY)
  return rawError
}

export class GoogleOAuthClient {
  private readonly clientID: string
  private readonly redirectURI: string

  private constructor(clientID: string, redirectURI: string) {
    this.clientID = clientID
    this.redirectURI = redirectURI
  }

  static fromEnv(env: GoogleOAuthEnv): GoogleOAuthClient {
    const clientID = env.VITE_GOOGLE_CLIENT_ID?.trim()
    if (!clientID) {
      throw new Error('Set VITE_GOOGLE_CLIENT_ID to use Google Calendar.')
    }

    const redirectURI = env.VITE_GOOGLE_OAUTH_REDIRECT_URI?.trim() || window.location.origin
    return new GoogleOAuthClient(clientID, redirectURI)
  }

  private startAuthorizationFlow(returnToPath: string, promptMode: OAuthPromptMode): void {
    const state = generateStateToken()
    window.sessionStorage.setItem(OAUTH_STATE_KEY, state)
    window.sessionStorage.setItem(OAUTH_RETURN_TO_KEY, normalizeReturnPath(returnToPath))
    window.sessionStorage.setItem(OAUTH_PROMPT_MODE_KEY, promptMode)

    const params = new URLSearchParams({
      client_id: this.clientID,
      redirect_uri: this.redirectURI,
      response_type: 'token',
      scope: OAUTH_SCOPES,
      include_granted_scopes: 'true',
      state,
      prompt: promptMode,
    })

    window.location.assign(`${OAUTH_ENDPOINT}?${params.toString()}`)
  }

  getSession(): GoogleAuthSession | null {
    const raw = readStoredSessionRaw()
    if (!raw) {
      return null
    }

    const session = parseStoredSession(raw)
    if (!session) {
      clearSession()
      return null
    }

    if (session.expiresAt <= Date.now()) {
      clearSession()
      return null
    }

    persistSignedInHint()
    return session
  }

  canAttemptSilentSignIn(): boolean {
    return hasSignedInHint() && !hasSilentAttemptBeenMade()
  }

  startSignIn(returnToPath: string): void {
    clearSilentAttempted()
    this.startAuthorizationFlow(returnToPath, 'select_account')
  }

  startSilentSignIn(returnToPath: string): void {
    if (!this.canAttemptSilentSignIn()) {
      return
    }

    markSilentAttempted()
    this.startAuthorizationFlow(returnToPath, 'none')
  }

  async getUserProfile(session: GoogleAuthSession, signal?: AbortSignal): Promise<GoogleUserProfile> {
    const response = await fetch(USER_INFO_ENDPOINT, {
      method: 'GET',
      headers: {
        Accept: 'application/json',
        Authorization: `Bearer ${session.accessToken}`,
      },
      signal,
    })

    if (!response.ok) {
      throw new Error(`Google profile request failed (${response.status})`)
    }

    const payload = (await response.json()) as GoogleUserInfoResponse
    if (typeof payload.sub !== 'string' || typeof payload.email !== 'string') {
      throw new Error('Google profile response was invalid.')
    }

    return {
      id: payload.sub,
      email: payload.email,
      name: payload.name ?? payload.email,
      picture: payload.picture ?? null,
    }
  }

  async signOut(session: GoogleAuthSession | null): Promise<void> {
    if (session?.accessToken) {
      try {
        await fetch(REVOKE_ENDPOINT, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: new URLSearchParams({ token: session.accessToken }),
        })
      } catch {
        // Best effort revoke. Local session is always cleared.
      }
    }

    clearSession()
    clearSignedInHint()
    clearSilentAttempted()
    clearOAuthState()
    window.sessionStorage.removeItem(OAUTH_RETURN_TO_KEY)
    window.sessionStorage.removeItem(OAUTH_ERROR_KEY)
  }
}
