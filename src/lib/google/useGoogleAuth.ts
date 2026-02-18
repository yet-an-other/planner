import { useCallback, useEffect, useMemo, useState } from 'react'
import { getGoogleOAuthEnv } from '../runtimeEnv'
import type { GoogleAuthSession, GoogleUserProfile } from './googleAuth.model'
import { GoogleOAuthClient, consumeGoogleOAuthError } from './googleOAuth'

type AuthStatus = 'loading' | 'authenticated' | 'unauthenticated'

type UseGoogleAuthResult = {
  authError: string | null
  profile: GoogleUserProfile | null
  session: GoogleAuthSession | null
  status: AuthStatus
  signIn: (returnToPath: string) => void
  signOut: () => Promise<void>
}

type OAuthSetup = {
  client: GoogleOAuthClient | null
  error: string | null
}

function buildOAuthSetup(): OAuthSetup {
  try {
    return {
      client: GoogleOAuthClient.fromEnv(getGoogleOAuthEnv()),
      error: null,
    }
  } catch (error) {
    return {
      client: null,
      error: (error as Error).message,
    }
  }
}

export function useGoogleAuth(): UseGoogleAuthResult {
  const oauthSetup = useMemo(() => buildOAuthSetup(), [])
  const [status, setStatus] = useState<AuthStatus>('loading')
  const [session, setSession] = useState<GoogleAuthSession | null>(null)
  const [profile, setProfile] = useState<GoogleUserProfile | null>(null)
  const [authError, setAuthError] = useState<string | null>(null)

  useEffect(() => {
    const controller = new AbortController()
    const { client, error } = oauthSetup

    async function initializeAuthState() {
      const redirectError = consumeGoogleOAuthError()
      if (redirectError) {
        setAuthError(redirectError)
      }

      if (error || !client) {
        setStatus('unauthenticated')
        setSession(null)
        setProfile(null)
        setAuthError((currentError) => currentError ?? error)
        return
      }

      const activeSession = client.getSession()
      if (!activeSession) {
        setStatus('unauthenticated')
        setSession(null)
        setProfile(null)
        return
      }

      setSession(activeSession)
      setStatus('loading')

      try {
        const nextProfile = await client.getUserProfile(activeSession, controller.signal)
        setProfile(nextProfile)
        setStatus('authenticated')
      } catch (error) {
        if ((error as Error).name === 'AbortError') {
          return
        }

        client.signOut(activeSession).catch(() => {
          // Ignore revoke errors and continue local cleanup.
        })
        setSession(null)
        setProfile(null)
        setStatus('unauthenticated')
        setAuthError((error as Error).message)
      }
    }

    void initializeAuthState()

    return () => {
      controller.abort()
    }
  }, [oauthSetup])

  const signIn = useCallback(
    (returnToPath: string) => {
      if (!oauthSetup.client) {
        setAuthError(oauthSetup.error ?? 'Google OAuth is not configured.')
        return
      }

      oauthSetup.client.startSignIn(returnToPath)
    },
    [oauthSetup],
  )

  const signOut = useCallback(async () => {
    if (oauthSetup.client) {
      await oauthSetup.client.signOut(session)
    }

    setSession(null)
    setProfile(null)
    setStatus('unauthenticated')
  }, [oauthSetup.client, session])

  return {
    authError,
    profile,
    session,
    status,
    signIn,
    signOut,
  }
}
